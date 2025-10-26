import '../../helpers/util.dart';
import '../../readers/file_reader.dart';
import '../../readers/reader.dart' show Reader;
import '../read_params.dart';
import 'jxl_generic.dart'
    // TODO: support Web platforms
    if (dart.library.io) 'jxl_vm.dart' as impl_;

class JxlExifReaderResult {
  final int? exifOffset;
  // Not null if exif data is compressed.
  // If exif data is not compressed, only [exifOffset] is set.
  final List<int>? exifData;

  JxlExifReaderResult(this.exifOffset, this.exifData);
}

abstract class JxlExifReader {
  Future<JxlExifReaderResult> findExif(FileReader f);

  static bool isJxl(List<int> header) => listRangeEqual(
        header,
        0,
        12,
        [
          0x00,
          0x00,
          0x00,
          0x0C,
          0x4A,
          0x58,
          0x4C,
          0x20,
          0x0D,
          0x0A,
          0x87,
          0x0A
        ],
      );

  static Future<ReadParams> readParams(FileReader f) async {
    final jxlReader = impl_.JxlExifReader();
    final res = await jxlReader.findExif(f);
    if (res.exifData != null && res.exifData!.isNotEmpty) {
      final endian = Reader.endianOfByte(res.exifData![0]);
      return ReadParams(endian: endian, data: res.exifData, offset: 0);
    }
    if (res.exifOffset == null) {
      return ReadParams.error('No exif found');
    }
    final offset = res.exifOffset!;
    final endianByte = await f.readByte();
    final endian = Reader.endianOfByte(endianByte);
    return ReadParams(endian: endian, offset: offset);
  }
}
