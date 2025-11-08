import 'dart:typed_data';

import 'package:random_access_source/random_access_source.dart';

import '../exif_types.dart';
import '../field_types.dart';
import '../helpers/uint8list_extension.dart';
import '../helpers/util.dart';
import '../makernotes/makernote_canon.dart' as canon_;

class BinaryReader {
  RandomAccessSource src;
  int baseOffset;
  Endian endian;

  BinaryReader(this.src, this.baseOffset, this.endian);

  Future<Uint8List> readSlice(int relativePos, int length) async {
    await src.seek(baseOffset + relativePos);
    return await src.read(length);
  }

  // Convert slice to integer, based on sign and endian flags.
  // Usually this offset is assumed to be relative to the beginning of the
  // start of the EXIF information.
  // For some cameras that use relative tags, this offset may be relative
  // to some other starting point.
  Future<int> readInt(int offset, int length, {bool signed = false}) async {
    final sliced = await readSlice(offset, length);
    int val;

    if (endian == Endian.little) {
      val = s2nLittleEndian(sliced, signed: signed);
    } else {
      val = s2nBigEndian(sliced, signed: signed);
    }

    return val;
  }

  Future<Ratio> readRatio(int offset, {required bool signed}) async {
    final n = await readInt(offset, 4, signed: signed);
    final d = await readInt(offset + 4, 4, signed: signed);
    return Ratio(n, d);
  }

  // Convert offset to string.
  List<int> offsetToBytes(int readOffset, int length) {
    final List<int> s = [];
    for (int dummy = 0; dummy < length; dummy++) {
      if (endian == Endian.little) {
        s.add(readOffset & 0xFF);
      } else {
        s.insert(0, readOffset & 0xFF);
      }
      readOffset = readOffset >> 8;
    }
    return s;
  }

  static Endian endianOfByte(int b) {
    if (b == 'I'.codeUnitAt(0)) {
      return Endian.little;
    }
    return Endian.big;
  }
}

class IfdReader {
  BinaryReader file;
  final bool fakeExif;

  IfdReader(this.file, {required this.fakeExif});

  // Return first IFD.
  Future<int> _firstIfd() => file.readInt(4, 4);

  // Return the pointer to next IFD.
  Future<int> _nextIfd(int ifd) async {
    final entries = await file.readInt(ifd, 2);
    final nextIfd = await file.readInt(ifd + 2 + 12 * entries, 4);
    if (nextIfd == ifd) {
      return 0;
    } else {
      return nextIfd;
    }
  }

  // Return the list of IFDs in the header.
  Future<List<int>> listIfd() async {
    int i = await _firstIfd();
    final List<int> ifds = [];
    while (i > 0) {
      ifds.add(i);
      i = await _nextIfd(i);
    }
    return ifds;
  }

  Future<List<IfdEntry>> readIfdEntries(
    int ifd, {
    required bool relative,
  }) async {
    final numEntries = await file.readInt(ifd, 2);

    final entries = <IfdEntry>[];
    for (int i = 0; i < numEntries; i++) {
      // entry is index of start of this IFD in the file
      final offset = ifd + 2 + 12 * i;
      final tag = await file.readInt(offset, 2);
      final fieldType = FieldType.ofValue(await file.readInt(offset + 2, 2));
      final count = await file.readInt(offset + 4, 4);

      final typeLength = fieldType.length;

      // Adjust for tag id/type/count (2+2+4 bytes)
      // Now we point at either the data or the 2nd level offset
      int fieldOffset = offset + 8;

      // If the value fits in 4 bytes, it is inlined, else we
      // need to jump ahead again.
      if (count * typeLength > 4) {
        // offset is not the value; it's a pointer to the value
        // if relative we set things up so s2n will seek to the right
        // place when it adds this.offset.  Note that this 'relative'
        // is for the Nikon type 3 makernote.  Other cameras may use
        // other relative offsets, which would have to be computed here
        // slightly differently.
        if (relative) {
          fieldOffset = await file.readInt(fieldOffset, 4) + ifd - 8;
          if (fakeExif) {
            fieldOffset += 18;
          }
        } else {
          fieldOffset = await file.readInt(fieldOffset, 4);
        }
      }

      final entry = IfdEntry(
        fieldOffset: fieldOffset,
        tag: tag,
        fieldType: fieldType,
        count: count,
      );
      entries.add(entry);
    }
    return entries;
  }

  Endian get endian => file.endian;

  set endian(Endian e) {
    file.endian = e;
  }

  int get baseOffset => file.baseOffset;

  set baseOffset(int v) {
    file.baseOffset = v;
  }

  Future<int> readInt(int offset, int length, {bool signed = false}) async {
    return file.readInt(offset, length, signed: signed);
  }

  Future<Uint8List> readSlice(int relativePos, int length) async {
    return file.readSlice(relativePos, length);
  }

  Future<IfdRatios> _readIfdRatios(IfdEntry entry) async {
    final List<Ratio> values = [];
    var pos = entry.fieldOffset;
    for (int dummy = 0; dummy < entry.count; dummy++) {
      values.add(await file.readRatio(pos, signed: entry.fieldType.isSigned));
      pos += entry.fieldType.length;
    }
    return IfdRatios(values);
  }

  Future<IfdInts> _readIfdInts(IfdEntry entry) async {
    final List<int> values = [];
    var pos = entry.fieldOffset;
    for (int dummy = 0; dummy < entry.count; dummy++) {
      values.add(
        await file.readInt(
          pos,
          entry.fieldType.length,
          signed: entry.fieldType.isSigned,
        ),
      );
      pos += entry.fieldType.length;
    }
    return IfdInts(values);
  }

  Future<IfdBytes> _readAscii(IfdEntry entry) async {
    var count = entry.count;
    // special case: null-terminated ASCII string
    // XXX investigate
    // sometimes gets too big to fit in int value
    if (count <= 0) {
      return IfdBytes.empty();
    }

    if (count > 1024 * 1024) {
      count = 1024 * 1024;
    }

    try {
      // and count < (2**31))  // 2E31 is hardware dependant. --gd
      var values = await file.readSlice(entry.fieldOffset, count);
      // Drop any garbage after a null.
      final i = values.indexOf(0);
      if (i >= 0) {
        values = values.subView(0, i);
      }
      return IfdBytes(values);
    } catch (e) {
      // warnings.add("exception($e) at position: $filePosition, length: $count");
      return IfdBytes.empty();
    }
  }

  Future<IfdValues> readField(IfdEntry entry, {required String tagName}) async {
    if (entry.fieldType == FieldType.ascii) {
      return _readAscii(entry);
    }

    // XXX investigate
    // some entries get too big to handle could be malformed
    // file or problem with this.s2n
    if (entry.count < 1000) {
      if (entry.fieldType == FieldType.ratio ||
          entry.fieldType == FieldType.signedRatio) {
        return _readIfdRatios(entry);
      } else {
        return _readIfdInts(entry);
      }
      // The test above causes problems with tags that are
      // supposed to have long values! Fix up one important case.
    } else if (tagName == 'MakerNote' ||
        tagName == canon_.MakerNoteCanon.cameraInfoTagName) {
      return _readIfdInts(entry);
    }
    return const IfdNone();
  }

  List<int> offsetToBytes(int readOffset, int length) {
    return file.offsetToBytes(readOffset, length);
  }
}

class IfdEntry {
  final int fieldOffset;
  final int tag;
  final FieldType fieldType;
  final int count;

  IfdEntry({
    required this.fieldOffset,
    required this.tag,
    required this.fieldType,
    required this.count,
  });
}
