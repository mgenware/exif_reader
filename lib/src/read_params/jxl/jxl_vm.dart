import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:iso_base_media/iso_base_media.dart';
import 'package:random_access_source/random_access_source.dart';

import '../../readers/file_reader.dart';
import '../../readers/file_reader_vm.dart' as io_;
import 'jxl.dart' as jxl_;

class JxlExifReader implements jxl_.JxlExifReader {
  @override
  Future<jxl_.JxlExifReaderResult> findExif(FileReader f) async {
    final reader = (f is io_.RandomAccessFileReader)
        ? f
        : throw Exception(
            'JXL is only supported via a RandomAccessFile reader.');
    final raSource =
        BytesRASource(Uint8List.fromList(await reader.readAsBytes(true)));
    await raSource.seek(await f.position());
    final fileBox = ISOBox.fileBox(raSource);
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
