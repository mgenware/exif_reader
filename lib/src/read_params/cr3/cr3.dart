import '../../helpers/util.dart';
import '../../readers/file_reader.dart';
import '../read_params.dart';
import 'cr3_generic.dart'
    // TODO: support Web platforms
    if (dart.library.io) 'cr3_vm.dart' as impl_;

abstract class Cr3ExifReader {
  Future<List<ReadParams>> findExif(FileReader f);

  static bool isCr3(List<int> header) =>
      listRangeEqual(header, 4, 12, 'ftypcrx '.codeUnits);

  static Future<List<ReadParams>> readParams(FileReader f) {
    final reader = impl_.Cr3ExifReader();
    return reader.findExif(f);
  }
}
