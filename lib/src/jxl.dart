import 'dart:io';

import 'package:brotli/brotli.dart';
import 'package:iso_base_media/iso_base_media.dart';

class JxlExifReaderResult {
  final int? exifOffset;
  // Not null if exif data is compressed.
  // If exif data is not compressed, only [exifOffset] is set.
  final List<int>? exifData;

  JxlExifReaderResult(this.exifOffset, this.exifData);
}

class JxlExifReader {
  final RandomAccessFile raf;

  const JxlExifReader(this.raf);

  Future<JxlExifReaderResult> findExif() async {
    final fileBox = ISOBox.fileBoxFromRandomAccessFile(raf);
    ISOBox? child;
    do {
      child = await fileBox.nextChild();
      if (child != null) {
        if (child.type == 'Exif') {
          return JxlExifReaderResult(
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
          if (headerString == 'Exif') {
            // Skip to 'Exif' header (which is compressed and right before compressed data).
            final brotliBytes = boxBytes.sublist(4);
            final decodedBytes = brotli.decode(brotliBytes);
            return JxlExifReaderResult(
                null,
                // Skip full box flag.
                // https://github.com/libjxl/libjxl/issues/3236
                decodedBytes.sublist(4));
          }
        }
      }
    } while (child != null);
    return JxlExifReaderResult(null, null);
  }
}
