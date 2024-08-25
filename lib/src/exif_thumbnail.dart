import 'dart:typed_data';

import 'exifheader.dart';
import 'field_types.dart';
import 'reader.dart';
import 'uint8list_extension.dart';

class Thumbnail {
  final Map<String, IfdTagImpl> tags;
  final IfdReader file;

  Thumbnail(this.tags, this.file);

  // Extract uncompressed TIFF thumbnail.
  // Take advantage of the pre-existing layout in the thumbnail IFD as
  // much as possible
  Future<Uint8List?> extractTiffThumbnail(int thumbIfd) async {
    final thumb = tags['Thumbnail Compression'];
    if (thumb == null || thumb.tag.printable != 'Uncompressed TIFF') {
      return null;
    }

    BytesBuilder tiff;
    int stripOff = 0;
    int stripLen = 0;

    final entries = await file.readInt(thumbIfd, 2);
    // this is header plus offset to IFD ...
    if (file.endian == Endian.big) {
      tiff = BytesBuilder();
      tiff.add('MM\x00*\x00\x00\x00\x08'.codeUnits);
    } else {
      tiff = BytesBuilder();
      tiff.add('II*\x00\x08\x00\x00\x00'.codeUnits);
      // ... plus thumbnail IFD data plus a null "next IFD" pointer
    }

    tiff.add(await file.readSlice(thumbIfd, entries * 12 + 2));
    tiff.add([0, 0, 0, 0]);

    // fix up large value offset pointers into data area
    for (int i = 0; i < entries; i++) {
      final entry = thumbIfd + 2 + 12 * i;
      final tag = await file.readInt(entry, 2);
      final fieldType = await file.readInt(entry + 2, 2);
      final typeLength = fieldTypes[fieldType].length;
      final count = await file.readInt(entry + 4, 4);
      final oldOffset = await file.readInt(entry + 8, 4);
      // start of the 4-byte pointer area in entry
      final ptr = i * 12 + 18;
      // remember strip offsets location
      if (tag == 0x0111) {
        stripOff = ptr;
        stripLen = count * typeLength;
        // is it in the data area?
      }
      if (count * typeLength > 4) {
        // update offset pointer (nasty "strings are immutable" crap)
        // should be able to say "tiff[ptr:ptr+4]=newOffset"
        final tiff0 = tiff;
        final tiff0Bytes = tiff0.toBytes();
        final newOffset = tiff0.length;
        tiff = BytesBuilder();
        tiff.add(tiff0Bytes.subView(0, ptr));
        tiff.add(file.offsetToBytes(newOffset, 4));
        tiff.add(tiff0Bytes.subView(ptr + 4));
        // remember strip offsets location
        if (tag == 0x0111) {
          stripOff = newOffset;
          stripLen = 4;
        }
        // get original data and store it
        tiff.add(await file.readSlice(oldOffset, count * typeLength));
      }
    }

    // add pixel strips and update strip offset info
    final oldOffsets = tags['Thumbnail StripOffsets']?.tag.values.toList();
    final oldCounts = tags['Thumbnail StripByteCounts']?.tag.values.toList();
    if (oldOffsets == null || oldCounts == null) {
      return null;
    }

    for (int i = 0; i < oldOffsets.length; i++) {
      // update offset pointer (more nasty "strings are immutable" crap)
      final tiff0 = tiff;
      final offset = file.offsetToBytes(tiff0.length, stripLen);
      final tiff0Bytes = tiff0.toBytes();
      tiff = BytesBuilder();
      tiff.add(tiff0Bytes.subView(0, stripOff));
      tiff.add(offset);
      tiff.add(tiff0Bytes.subView(stripOff + stripLen));
      stripOff += stripLen;
      // add pixel strip to end
      tiff.add(
        await file.readSlice(
          oldOffsets[i] as int,
          oldCounts[i] as int,
        ),
      );
    }

    return tiff.toBytes();
  }

  // Extract JPEG thumbnail.
  // (Thankfully the JPEG data is stored as a unit.)
  Future<List<int>?> extractJpegThumbnail() async {
    final thumbFmt = tags['Thumbnail JPEGInterchangeFormat'];
    final thumbFmtLen = tags['Thumbnail JPEGInterchangeFormatLength'];
    if (thumbFmt != null && thumbFmtLen != null) {
      final size = thumbFmtLen.tag.values.firstAsInt();
      final values =
          await file.readSlice(thumbFmt.tag.values.firstAsInt(), size);
      return values;
    }

    // Sometimes in a TIFF file, a JPEG thumbnail is hidden in the MakerNote
    // since it's not allowed in a uncompressed TIFF IFD
    final thumbnail = tags['MakerNote JPEGThumbnail'];
    if (thumbnail != null) {
      final values = await file.readSlice(
        thumbnail.tag.values.firstAsInt(),
        thumbnail.fieldLength,
      );
      return values;
    }

    return null;
  }
}
