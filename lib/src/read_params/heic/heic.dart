import 'dart:typed_data';

import '../../helpers/util.dart';
import '../../readers/file_reader.dart';
import '../../readers/reader.dart' show Reader;
import '../read_params.dart';

class HeicBox {
  final String name;

  int version = 0;
  int minorVersion = 0;
  int itemCount = 0;
  int size = 0;
  int after = 0;
  int pos = 0;
  List<Uint8List> compat = [];

  // this is full of boxes, but not in a predictable order.
  Map<String, HeicBox> subs = {};
  Map<int, List<List<int>>> locs = {};
  HeicBox? exifInfe;
  int itemId = 0;
  Uint8List? itemType;
  Uint8List? itemName;
  int itemProtectionIndex = 0;
  Uint8List? majorBrand;
  int flags = 0;

  HeicBox(this.name);

  void setFull(int vflags) {
    /**
        ISO boxes come in 'old' and 'full' variants.
        The 'full' variant contains version and flags information.
     */
    version = (vflags >> 24) & 0xff;
    flags = vflags & 0xffffff;
  }
}

class HEICExifFinder {
  final FileReader fileReader;

  HEICExifFinder(this.fileReader);

  static Future<ReadParams> readParams(FileReader f) async {
    await f.setPosition(0);
    final heic = HEICExifFinder(f);
    final res = await heic.findExif();
    if (res.length != 2) {
      return ReadParams.error('Possibly corrupted heic data');
    }
    final int offset = res[0];
    final Endian endian = Reader.endianOfByte(res[1]);
    return ReadParams(endian: endian, offset: offset);
  }

  static bool isHeif(List<int> header) {
    try {
      final ftyp = listRangeToAsciiString(header, 4, 12);
      if (ftyp == null) {
        return false;
      }
      return _heifFtyp.contains(ftyp);
    } catch (e) {
      return false;
    }
  }

  static bool isAvif(List<int> header) =>
      listRangeEqual(header, 4, 12, 'ftypavif'.codeUnits);

  Future<Uint8List> getBytes(int nbytes) async {
    final bytes = await fileReader.read(nbytes);
    if (bytes.length != nbytes) {
      throw Exception('Bad size');
    }
    return Uint8List.fromList(bytes);
  }

  Future<int> getInt(int size) async {
    // some fields have variant-sized data.
    if (size == 2) {
      return ByteData.view((await getBytes(2)).buffer).getInt16(0);
    }
    if (size == 4) {
      return ByteData.view((await getBytes(4)).buffer).getInt32(0);
    }
    if (size == 8) {
      return ByteData.view((await getBytes(8)).buffer).getInt64(0);
    }
    if (size == 0) {
      return 0;
    }
    throw Exception('Bad size');
  }

  Future<Uint8List> getString() async {
    final List<Uint8List> read = [];
    while (true) {
      final char = await getBytes(1);
      if (listEqual(char, Uint8List.fromList('\x00'.codeUnits))) {
        break;
      }
      read.add(char);
    }
    return Uint8List.fromList(read.expand((x) => x).toList());
  }

  Future<List<int>> getInt4x2() async {
    final num = (await getBytes(1)).single;
    final num0 = num >> 4;
    final num1 = num & 0xf;
    return [num0, num1];
  }

  Future<HeicBox> nextBox() async {
    final pos = await fileReader.position();
    int size = ByteData.view((await getBytes(4)).buffer).getInt32(0);
    final kind = String.fromCharCodes(await getBytes(4));
    final box = HeicBox(kind);
    if (size == 0) {
      //  signifies 'to the end of the file', we shouldn't see this.
      throw Exception('Unknown error');
    }
    if (size == 1) {
      // 64-bit size follows type.
      size = ByteData.view((await getBytes(8)).buffer).getInt64(0);
      box.size = size - 16;
      box.after = pos + size;
    } else {
      box.size = size - 8;
      box.after = pos + size;
    }
    box.pos = await fileReader.position();
    return box;
  }

  Future<void> _parseFtyp(HeicBox box) async {
    box.majorBrand = await getBytes(4);
    box.minorVersion = ByteData.view((await getBytes(4)).buffer).getInt32(0);
    box.compat = [];
    int size = box.size - 8;
    while (size > 0) {
      box.compat.add(await getBytes(4));
      size -= 4;
    }
  }

  Future<void> _parseMeta(HeicBox meta) async {
    meta.setFull(ByteData.view((await getBytes(4)).buffer).getInt32(0));
    while (await fileReader.position() < meta.after) {
      final box = await nextBox();
      final psub = getParser(box);
      if (psub != null) {
        await psub(box);
        meta.subs[box.name] = box;
      }
      // skip any unparsed data
      await fileReader.setPosition(box.after);
    }
  }

  Future<void> _parseInfe(HeicBox box) async {
    box.setFull(ByteData.view((await getBytes(4)).buffer).getInt32(0));
    if (box.version >= 2) {
      if (box.version == 2) {
        box.itemId = ByteData.view((await getBytes(2)).buffer).getInt16(0);
      } else if (box.version == 3) {
        box.itemId = ByteData.view((await getBytes(4)).buffer).getInt32(0);
      }
      box.itemProtectionIndex =
          ByteData.view((await getBytes(2)).buffer).getInt16(0);
      box.itemType = await getBytes(4);
      box.itemName = await getString();
      // ignore the rest
    }
  }

  Future<void> _parseIinf(HeicBox box) async {
    box.setFull(ByteData.view((await getBytes(4)).buffer).getInt32(0));
    int count;
    if (box.version == 0) {
      count = ByteData.view((await getBytes(2)).buffer).getInt16(0);
    } else {
      count = ByteData.view((await getBytes(4)).buffer).getInt32(0);
    }

    box.exifInfe = null;
    for (var i = 0; i < count; i += 1) {
      final infe = await expectParse('infe');
      if (listEqual(infe.itemType, Uint8List.fromList('Exif'.codeUnits))) {
        box.exifInfe = infe;
        break;
      }
    }
  }

  Future<void> _parseIloc(HeicBox box) async {
    box.setFull(ByteData.view((await getBytes(4)).buffer).getInt32(0));
    final size = await getInt4x2();
    final size2 = await getInt4x2();

    final offsetSize = size[0];
    final lengthSize = size[1];
    final baseOffsetSize = size2[0];
    final indexSize = size2[1];

    if (box.version < 2) {
      box.itemCount = ByteData.view((await getBytes(2)).buffer).getInt16(0);
    } else if (box.version == 2) {
      box.itemCount = ByteData.view((await getBytes(4)).buffer).getInt32(0);
    } else {
      throw Exception('Box version 2, ${box.version}');
    }
    box.locs = {};
    for (var i = 0; i < box.itemCount; i += 1) {
      int itemId;
      if (box.version < 2) {
        itemId = ByteData.view((await getBytes(2)).buffer).getInt16(0);
      } else if (box.version == 2) {
        itemId = ByteData.view((await getBytes(4)).buffer).getInt32(0);
      } else {
        throw Exception('Box version 2, ${box.version}');
      }

      if (box.version == 1 || box.version == 2) {
        // ignore construction_method
        ByteData.view((await getBytes(2)).buffer).getInt16(0);
      }
      // ignore data_reference_index
      ByteData.view((await getBytes(2)).buffer).getInt16(0);
      final baseOffset = await getInt(baseOffsetSize);
      final extentCount = ByteData.view((await getBytes(2)).buffer).getInt16(0);
      final List<List<int>> extent = [];
      for (var i = 0; i < extentCount; i += 1) {
        if ((box.version == 1 || box.version == 2) && indexSize > 0) {
          await getInt(indexSize);
        }
        final extentOffset = await getInt(offsetSize);
        final extentLength = await getInt(lengthSize);
        extent.add([baseOffset + extentOffset, extentLength]);
      }
      box.locs[itemId] = extent;
    }
  }

  Future<void> Function(HeicBox)? getParser(HeicBox box) {
    final defs = {
      'ftyp': _parseFtyp,
      'meta': _parseMeta,
      'infe': _parseInfe,
      'iinf': _parseIinf,
      'iloc': _parseIloc,
    };
    return defs[box.name];
  }

  Future<HeicBox> parseBox(HeicBox box) async {
    final probe = getParser(box);
    if (probe == null) {
      throw Exception('Unhandled box');
    }
    await probe(box);
    //  in case anything is left unread
    await fileReader.setPosition(box.after);
    return box;
  }

  Future<HeicBox> expectParse(String name) async {
    while (true) {
      final box = await nextBox();
      if (box.name == name) {
        return parseBox(box);
      }
      await fileReader.setPosition(box.after);
    }
  }

  Future<List<int>> findExif() async {
    await expectParse('ftyp');
    final meta = await expectParse('meta');
    final itemId = meta.subs['iinf']?.exifInfe?.itemId;
    if (itemId == null) {
      return [];
    }
    final extents = meta.subs['iloc']?.locs[itemId];
    // we expect the Exif data to be in one piece.
    if (extents == null || extents.length != 1) {
      return [];
    }
    final int pos = extents[0][0];
    // looks like there's a kind of pseudo-box here.
    await fileReader.setPosition(pos);
    // the payload of "Exif" item may be start with either
    //  b'\xFF\xE1\xSS\xSSExif\x00\x00' (with APP1 marker, e.g. Android Q)
    //  or
    // b'Exif\x00\x00' (without APP1 marker, e.g. iOS)
    // according to "ISO/IEC 23008-12, 2017-12", both of them are legal
    final exifTiffHeaderOffset =
        ByteData.view((await getBytes(4)).buffer).getInt32(0);
    await getBytes(exifTiffHeaderOffset);
    // assert self.get(exif_tiff_header_offset)[-6:] == b'Exif\x00\x00'
    final offset = await fileReader.position();
    final endian = (await fileReader.read(1))[0];
    return [offset, endian];
  }
}

final _heifFtyp = {
  'ftypheic',
  'ftypheix',
  'ftyphevc',
  'ftyphevx',
  'ftypmif1',
  'ftypmsf1',
};
