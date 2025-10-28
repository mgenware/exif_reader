import '../../helpers/util.dart';
import '../../readers/file_reader.dart';
import '../../readers/reader.dart';
import '../read_params.dart';

class TiffExifReader {
  /// Returns true if the header indicates a TIFF file.
  static bool isTiff(List<int> header) {
    return header.length >= 4 &&
        listContainedIn(
          header.sublist(0, 4),
          ['II*\x00'.codeUnits, 'MM\x00*'.codeUnits],
        );
  }

  /// Reads TIFF EXIF parameters from a [FileReader].
  /// Returns a [ReadParams] object.
  static Future<ReadParams> readParams(FileReader f) async {
    await f.setPosition(0);
    final endian = Reader.endianOfByte(await f.readByte());
    await f.read(1);
    return ReadParams(endian: endian, offset: 0);
  }
}
