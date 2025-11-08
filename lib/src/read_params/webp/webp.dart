import 'dart:typed_data';

import 'package:random_access_source/random_access_source.dart';

import '../../helpers/uint8list_extension.dart';
import '../../helpers/util.dart';
import '../../readers/reader.dart';
import '../read_params.dart';

class WebpExifReader {
  /// Returns true if the header indicates a WebP file.
  static bool isWebp(List<int> header) {
    return listRangeEqual(header, 0, 4, 'RIFF'.codeUnits) &&
        listRangeEqual(header, 8, 12, 'WEBP'.codeUnits);
  }

  static Future<ReadParams> readParams(RandomAccessSource src) async {
    // Each RIFF box is a 4-byte ASCII tag, followed by a little-endian uint32 length and data.
    // The file starts with an outer box 'RIFF', whose content is the file format ('WEBP')
    // followed by a series of inner boxes. We need the inner 'EXIF' box.
    await src.seek(12);
    while (true) {
      final header = await src.read(8);
      if (header.length < 8) {
        return ReadParams.error('Invalid RIFF encoding');
      }

      final tag = String.fromCharCodes(header.subView(0, 4));
      final length = Int8List.fromList(header.subView(4, 8))
          .buffer
          .asByteData()
          .getInt32(0, Endian.little);

      // WebP uses "EXIF" as tag name.
      if (tag == 'EXIF') {
        // Look for Exif\x00\x00, and skip it if present.
        final exifHeader = await src.read(6);
        if (!listEqual(
          exifHeader,
          Uint8List.fromList('Exif\x00\x00'.codeUnits),
        )) {
          await src.seek(await src.position() - exifHeader.length);
        }

        final offset = await src.position();
        final endian = BinaryReader.endianOfByte(await src.readByte());
        return ReadParams(endian: endian, offset: offset);
      }

      // Skip forward to the next box.
      await src.seek(await src.position() + length);
    }
  }
}
