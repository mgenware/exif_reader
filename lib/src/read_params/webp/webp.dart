import 'dart:typed_data';

import '../../helpers/util.dart';
import '../../readers/file_reader.dart' show FileReader;
import '../../readers/reader.dart';
import '../read_params.dart';

class WebpExifReader {
  /// Returns true if the header indicates a WebP file.
  static bool isWebp(List<int> header) {
    return listRangeEqual(header, 0, 4, 'RIFF'.codeUnits) &&
        listRangeEqual(header, 8, 12, 'WEBP'.codeUnits);
  }

  /// Reads WebP EXIF parameters from a [FileReader].
  /// Returns a [ReadParams] object or error.
  static Future<ReadParams> readParams(FileReader f) async {
    // Each RIFF box is a 4-byte ASCII tag, followed by a little-endian uint32 length and data.
    // The file starts with an outer box 'RIFF', whose content is the file format ('WEBP')
    // followed by a series of inner boxes. We need the inner 'EXIF' box.
    await f.setPosition(12);
    while (true) {
      final header = await f.read(8);
      if (header.length < 8) {
        return ReadParams.error('Invalid RIFF encoding');
      }

      final tag = String.fromCharCodes(header.sublist(0, 4));
      final length = Int8List.fromList(header.sublist(4, 8))
          .buffer
          .asByteData()
          .getInt32(0, Endian.little);

      // WebP uses "EXIF" as tag name.
      if (tag == 'EXIF') {
        // Look for Exif\x00\x00, and skip it if present.
        final exifHeader = await f.read(6);
        if (!listEqual(
          exifHeader,
          Uint8List.fromList('Exif\x00\x00'.codeUnits),
        )) {
          await f.setPosition(await f.position() - exifHeader.length);
        }

        final offset = await f.position();
        final endian = Reader.endianOfByte(await f.readByte());
        return ReadParams(endian: endian, offset: offset);
      }

      // Skip forward to the next box.
      await f.setPosition(await f.position() + length);
    }
  }
}
