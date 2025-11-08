import 'package:random_access_source/random_access_source.dart';

import '../../helpers/util.dart';
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

  static Future<ReadParams> readParams(RandomAccessSource src) async {
    await src.seek(0);
    final endian = BinaryReader.endianOfByte(await src.readByte());
    await src.read(1);
    return ReadParams(endian: endian, offset: 0);
  }
}
