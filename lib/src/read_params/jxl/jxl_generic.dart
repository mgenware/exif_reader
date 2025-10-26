import '../../readers/file_reader.dart';
import 'jxl.dart' as jxl_;

class JxlExifReader implements jxl_.JxlExifReader {
  @override
  Future<jxl_.JxlExifReaderResult> findExif(FileReader f) =>
      throw UnsupportedError('JXL is not supported on this platform.');
}
