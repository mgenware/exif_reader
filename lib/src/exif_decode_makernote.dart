import 'dart:typed_data';

import 'exifheader.dart';
import 'field_types.dart';
import 'makernote_apple.dart';
import 'makernote_canon.dart';
import 'makernote_casio.dart';
import 'makernote_fujifilm.dart';
import 'makernote_nikon.dart';
import 'makernote_olympus.dart';
import 'reader.dart';
import 'tags_info.dart';
import 'util.dart';

class DecodeMakerNote {
  final Map<String, IfdTagImpl> tags;
  final IfdReader file;

  Future<void> Function(
    int ifd,
    String ifdName, {
    Map<int, MakerTag>? tagDict,
    bool relative,
  }) dumpIfdFunc;

  DecodeMakerNote(this.tags, this.file, this.dumpIfdFunc);

  // deal with MakerNote contained in EXIF IFD
  // (Some apps use MakerNote tags but do not use a format for which we
  // have a description, do not process these).
  Future<void> decode() async {
    final note = tags['EXIF MakerNote'];
    if (note == null) {
      return;
    }

    // Some apps use MakerNote tags but do not use a format for which we
    // have a description, so just do a raw dump for these.
    final make = tags['Image Make']?.tag.printable ?? '';
    if (make == '') {
      return;
    }

    await _decodeMakerNote(note: note, make: make);
  }

  // Decode all the camera-specific MakerNote formats
  // Note is the data that comprises this MakerNote.
  // The MakerNote will likely have pointers in it that point to other
  // parts of the file. We'll use this.offset as the starting point for
  // most of those pointers, since they are relative to the beginning
  // of the file.
  // If the MakerNote is in a newer format, it may use relative addressing
  // within the MakerNote. In that case we'll use relative addresses for
  // the pointers.
  // As an aside: it's not just to be annoying that the manufacturers use
  // relative offsets.  It's so that if the makernote has to be moved by the
  // picture software all of the offsets don't have to be adjusted.  Overall,
  // this is probably the right strategy for makernotes, though the spec is
  // ambiguous.
  // The spec does not appear to imagine that makernotes would
  // follow EXIF format internally.  Once they did, it's ambiguous whether
  // the offsets should be from the header at the start of all the EXIF info,
  // or from the header at the start of the makernote.
  Future<void> _decodeMakerNote({
    required IfdTagImpl note,
    required String make,
  }) async {
    if (await _decodeNikon(note, make)) {
      return;
    }

    if (await _decodeOlympus(note, make)) {
      return;
    }

    if (await _decodeCasio(note, make)) {
      return;
    }

    if (await _decodeFujifilm(note, make)) {
      return;
    }

    if (await _decodeApple(note, make)) {
      return;
    }

    if (await _decodeCanon(note, make)) {
      return;
    }
  }

  Future<bool> _decodeNikon(IfdTagImpl note, String make) async {
    // Nikon
    // The maker note usually starts with the word Nikon, followed by the
    // type of the makernote (1 or 2, as a short).  If the word Nikon is
    // not at the start of the makernote, it's probably type 2, since some
    // cameras work that way.
    if (!make.contains('NIKON')) {
      return false;
    }

    if (listHasPrefix(
      note.tag.values.toList(),
      [78, 105, 107, 111, 110, 0, 1],
    )) {
      // Looks like a type 1 Nikon MakerNote
      await _dumpIfd(note.fieldOffset + 8, tagDict: MakerNoteNikon.tagsOld);
    } else if (listHasPrefix(
      note.tag.values.toList(),
      [78, 105, 107, 111, 110, 0, 2],
    )) {
      // Looks like a labeled type 2 Nikon MakerNote
      if (!listHasPrefix(note.tag.values.toList(), [0, 42], start: 12) &&
          !listHasPrefix(note.tag.values.toList(), [42, 0], start: 12)) {
        throw const FormatException("Missing marker tag '42' in MakerNote.");
        // skip the Makernote label and the TIFF header
      }
      await _dumpIfd(
        note.fieldOffset + 10 + 8,
        tagDict: MakerNoteNikon.tagsNew,
        relative: true,
      );
    } else {
      // E99x or D1
      // Looks like an unlabeled type 2 Nikon MakerNote
      await _dumpIfd(note.fieldOffset, tagDict: MakerNoteNikon.tagsNew);
    }
    return true;
  }

  Future<bool> _decodeOlympus(IfdTagImpl note, String make) async {
    if (make.startsWith('OLYMPUS')) {
      await _dumpIfd(note.fieldOffset + 8, tagDict: MakerNoteOlympus.tags);
      // TODO
      //for i in (('MakerNote Tag 0x2020', makernote.OLYMPUS_TAG_0x2020),):
      //    this.decode_olympus_tag(tags[i[0]].values, i[1])
      //return
      return true;
    }
    return false;
  }

  Future<bool> _decodeCasio(IfdTagImpl note, String make) async {
    if (make.contains('CASIO') || make.contains('Casio')) {
      await _dumpIfd(note.fieldOffset, tagDict: MakerNoteCasio.tags);
      return true;
    }
    return false;
  }

  Future<bool> _decodeFujifilm(IfdTagImpl note, String make) async {
    if (make != 'FUJIFILM') {
      return false;
    }

    // bug: everything else is "Motorola" endian, but the MakerNote
    // is "Intel" endian
    const endian = Endian.little;

    // bug: IFD offsets are from beginning of MakerNote, not
    // beginning of file header
    final newBaseOffset = file.baseOffset + note.fieldOffset;

    // process note with bogus values (note is actually at offset 12)
    await _dumpIfd2(
      12,
      tagDict: MakerNoteFujifilm.tags,
      baseOffset: newBaseOffset,
      endian: endian,
    );

    return true;
  }

  Future<bool> _decodeApple(IfdTagImpl note, String make) async {
    if (!_makerIsApple(note, make)) {
      return false;
    }

    final newBaseOffset = file.baseOffset + note.fieldOffset + 14;

    await _dumpIfd2(
      0,
      tagDict: MakerNoteApple.tags,
      baseOffset: newBaseOffset,
      endian: file.endian,
    );

    return true;
  }

  bool _makerIsApple(IfdTagImpl note, String make) =>
      make == 'Apple' &&
      listHasPrefix(
        note.tag.values.toList(),
        [65, 112, 112, 108, 101, 32, 105, 79, 83, 0],
      );

  Future<bool> _decodeCanon(IfdTagImpl note, String make) async {
    if (make != 'Canon') {
      return false;
    }

    await _dumpIfd(note.fieldOffset, tagDict: MakerNoteCanon.tags);
    postProcessCanonTags(tags);
    return true;
  }

  static void postProcessCanonTags(Map<String, IfdTagImpl> tags) {
    MakerNoteCanon.tagsXxx.forEach((name, makerTags) {
      final tag = tags[name];
      if (tag != null) {
        _canonDecodeTag(
          tags,
          tag.tag.values.toList().whereType<int>().toList(),
          makerTags,
        );
        tags.remove(name);
      }
    });

    final cannonTag = tags[MakerNoteCanon.cameraInfoTagName];
    if (cannonTag != null) {
      _canonDecodeCameraInfo(tags, cannonTag);
      tags.remove(MakerNoteCanon.cameraInfoTagName);
    }
  }

  // TODO Decode Olympus MakerNote tag based on offset within tag
  // void _olympus_decode_tag(List<int> value, mn_tags) {}

  // Decode Canon MakerNote tag based on offset within tag.
  // See http://www.burren.cx/david/canon.html by David Burren
  static void _canonDecodeTag(Map<String, IfdTagImpl> tags, List<int> value,
      Map<int, MakerTag> mnTags) {
    for (int i = 1; i < value.length; i++) {
      final tag = mnTags[i] ?? MakerTag.make('Unknown');
      final name = tag.name;
      String val;
      if (tag.map != null) {
        val = tag.map![value[i]] ?? 'Unknown';
      } else {
        val = value[i].toString();
      }

      // it's not a real IFD Tag but we fake one to make everybody
      // happy. this will have a "proprietary" type
      tags['MakerNote $name'] = IfdTagImpl(printable: val);
    }
  }

  // Decode the variable length encoded camera info section.
  static void _canonDecodeCameraInfo(
      Map<String, IfdTagImpl> tags, IfdTagImpl cameraInfoTag) {
    final modelTag = tags['Image Model'];
    if (modelTag == null) {
      return;
    }

    final model = modelTag.tag.values.toString();

    Map<int, CameraInfo>? cameraInfoTags;
    for (final modelNameRegExp in MakerNoteCanon.cameraInfoModelMap.keys) {
      final tagDesc = MakerNoteCanon.cameraInfoModelMap[modelNameRegExp];
      if (RegExp(modelNameRegExp).hasMatch(model)) {
        cameraInfoTags = tagDesc;
        break;
      }
    }

    if (cameraInfoTags == null) {
      return;
    }

    // We are assuming here that these are all unsigned bytes (Byte or
    // Unknown)
    if (cameraInfoTag.fieldType != FieldType.byte &&
        cameraInfoTag.fieldType != FieldType.undefined) {
      return;
    }

    if (cameraInfoTag.tag.values is! List<int>) {
      return;
    }

    final cameraInfo = cameraInfoTag.tag.values as List<int>;

    // Look for each data value and decode it appropriately.
    for (final entry in cameraInfoTags.entries) {
      final offset = entry.key;
      final tag = entry.value;
      final tagSize = tag.tagSize;
      if (cameraInfo.length < offset + tagSize) {
        continue;
      }

      final packedTagValue = cameraInfo.sublist(offset, offset + tagSize);
      final tagValue = s2nLittleEndian(packedTagValue);

      tags['MakerNote ${tag.tagName}'] =
          IfdTagImpl(printable: tag.function(tagValue));
    }
  }

  Future<void> _dumpIfd(
    int ifd, {
    required Map<int, MakerTag> tagDict,
    bool relative = false,
  }) async {
    await dumpIfdFunc(ifd, 'MakerNote', tagDict: tagDict, relative: relative);
  }

  Future<void> _dumpIfd2(
    int ifd, {
    required Map<int, MakerTag>? tagDict,
    bool relative = false,
    required int baseOffset,
    required Endian endian,
  }) async {
    final originalEndian = file.endian;
    final originalOffset = file.baseOffset;

    file.endian = endian;
    file.baseOffset = baseOffset;

    await dumpIfdFunc(ifd, 'MakerNote', tagDict: tagDict, relative: relative);

    file.endian = originalEndian;
    file.baseOffset = originalOffset;
  }
}
