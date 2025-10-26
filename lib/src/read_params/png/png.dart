import 'dart:typed_data';

import '../../helpers/util.dart';
import '../../readers/file_reader.dart' show FileReader;
import '../../readers/reader.dart';
import '../read_params.dart';

class PngExifReader {
  /// Returns true if the header indicates a PNG file.
  static bool isPng(List<int> header) {
    return listRangeEqual(header, 0, 8, '\x89PNG\r\n\x1a\n'.codeUnits);
  }

  /// Reads PNG EXIF parameters from a [FileReader].
  /// Returns a [ReadParams] object or error.
  static Future<ReadParams> readParams(FileReader f) async {
    await f.setPosition(8);
    while (true) {
      final data = await f.read(8);
      if (data.length < 8) {
        return ReadParams.error('Invalid PNG encoding');
      }
      final chunk = String.fromCharCodes(data.sublist(4, 8));

      if (chunk.isEmpty || chunk == 'IEND') {
        break;
      }
      if (chunk == 'eXIf') {
        final offset = await f.position();
        final endian = Reader.endianOfByte(await f.readByte());
        return ReadParams(endian: endian, offset: offset);
      }

      final chunkSize =
          Int8List.fromList(data.sublist(0, 4)).buffer.asByteData().getInt32(0);
      await f.setPosition(await f.position() + chunkSize + 4);
    }

    return ReadParams.error('No EXIF information found');
  }
}
