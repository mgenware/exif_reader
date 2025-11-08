import 'dart:convert';

import 'package:random_access_source/random_access_source.dart';

import '../../helpers/util.dart';
import '../../readers/reader.dart';
import '../read_params.dart';

final _exifHeader = AsciiCodec().decode([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]);

class RafExifReader {
  /// Returns true if the header indicates a FUJI RAF file.
  static bool isRaf(List<int> header) =>
      listRangeEqual(header, 0, 15, 'FUJIFILMCCD-'.codeUnits);

  static Future<ReadParams> readParams(RandomAccessSource src) async {
    await src.seek(0);
    final readParams = await _findExif(src);
    return readParams ?? ReadParams.error('No EXIF information found');
  }

  static Future<ReadParams?> _findExif(RandomAccessSource src) async {
    final bytes = await src.readToEnd();
    final asciiString = AsciiCodec().decode(bytes, allowInvalid: true);
    final index = asciiString.indexOf(_exifHeader);
    if (index == -1) {
      return null;
    }
    // Get the staring position of the Exif data.
    final exifStart = index + _exifHeader.length;
    if (exifStart + 2 >= bytes.length) {
      return null;
    }
    final endianByte = bytes[exifStart];
    final endian = BinaryReader.endianOfByte(endianByte);
    return ReadParams(
      offset: exifStart,
      endian: endian,
    );
  }
}
