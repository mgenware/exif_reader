import 'package:brotli/brotli.dart';
import 'package:iso_base_media/iso_base_media.dart';

import '../../readers/file_reader.dart';
import '../../readers/file_reader_vm.dart' as io_;
import 'jxl.dart' as jxl_;

class JxlExifReader implements jxl_.JxlExifReader {
  @override
  Future<jxl_.JxlExifReaderResult> findExif(FileReader fileReader) async {
    final raf = (fileReader is io_.RandomAccessFileReader)
        ? fileReader.file
        : throw Exception(
            'JXL is only supported via a RandomAccessFile reader.');
    final fileBox = ISOBox.fileBoxFromRandomAccessFile(raf);
    ISOBox? child;
    do {
      child = await fileBox.nextChild();
      if (child != null) {
        if (child.type.toLowerCase() == 'exif') {
          return jxl_.JxlExifReaderResult(
              child.dataOffset
                  // Skip full box flag.
                  // https://github.com/libjxl/libjxl/issues/3236
                  +
                  4,
              null);
        } else if (child.type == 'brob') {
          final boxBytes = await child.extractData();
          final header = boxBytes.sublist(0, 4);
          final headerString = String.fromCharCodes(header);
          if (headerString.toLowerCase() == 'exif') {
            // Skip to 'Exif' header (which is compressed and right before compressed data).
            final brotliBytes = boxBytes.sublist(4);
            final decodedBytes = brotli.decode(brotliBytes);
            return jxl_.JxlExifReaderResult(
                null,
                // Skip full box flag.
                // https://github.com/libjxl/libjxl/issues/3236
                decodedBytes.sublist(4));
          }
        }
      }
    } while (child != null);
    return jxl_.JxlExifReaderResult(null, null);
  }
}
