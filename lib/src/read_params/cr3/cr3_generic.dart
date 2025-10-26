import '../../readers/file_reader.dart' show FileReader;
import '../read_params.dart';
import 'cr3.dart' as cr3_;

class Cr3ExifReader implements cr3_.Cr3ExifReader {
  @override
  Future<List<ReadParams>> findExif(FileReader f) =>
      throw UnsupportedError('CR3 is not supported on this platform.');
}
