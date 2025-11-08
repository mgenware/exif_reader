import 'dart:typed_data';

import 'package:random_access_source/random_access_source.dart';

import '../../helpers/uint8list_extension.dart';
import '../../helpers/util.dart';
import '../../readers/reader.dart';
import '../read_params.dart';

class PngExifReader {
  /// Returns true if the header indicates a PNG file.
  static bool isPng(List<int> header) {
    return listRangeEqual(header, 0, 8, '\x89PNG\r\n\x1a\n'.codeUnits);
  }

  static Future<ReadParams> readParams(RandomAccessSource src) async {
    await src.seek(8);
    while (true) {
      final data = await src.read(8);
      if (data.length < 8) {
        return ReadParams.error('Invalid PNG encoding');
      }
      final chunk = String.fromCharCodes(data.subView(4));

      if (chunk.isEmpty || chunk == 'IEND') {
        break;
      }
      if (chunk == 'eXIf') {
        final offset = await src.position();
        final endian = BinaryReader.endianOfByte(await src.readByte());
        return ReadParams(endian: endian, offset: offset);
      }

      final chunkSize =
          Int8List.fromList(data.subView(0, 4)).buffer.asByteData().getInt32(0);
      await src.seek(await src.position() + chunkSize + 4);
    }

    return ReadParams.error('No EXIF information found');
  }
}
