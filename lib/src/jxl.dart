import 'dart:io';

import 'package:es_compression/brotli.dart';
import 'package:iso_base_media/iso_base_media.dart';

class JxlExifReaderResult {
  final int? exifOffset;
  final List<int>? exifData;

  JxlExifReaderResult(this.exifOffset, this.exifData);
}

class JxlExifReader {
  final RandomAccessFile raf;

  const JxlExifReader(this.raf);

  Future<JxlExifReaderResult> findExif() async {
    final fileBox = await ISOFileBox.openRandomAccessFile(raf);
    ISOBox? child;
    do {
      child = await fileBox.nextChild();
      if (child != null) {
        if (child.type == 'Exif') {
          return JxlExifReaderResult(
              child.dataOffset
                  // Skip full box flag.
                  +
                  4,
              null);
        } else if (child.type == 'brob') {
          final brobBytes = await child.extractData();
          final header = brobBytes.sublist(0, 4);
          final headerString = String.fromCharCodes(header);
          if (headerString == 'Exif') {
            // Skip header.
            final contentBytes = brobBytes.sublist(4);
            final decodedBytes = brotli.decode(contentBytes);
            return JxlExifReaderResult(
                null,
                // Skip full box flag.
                decodedBytes.sublist(4));
          }
        }
      }
    } while (child != null);
    return JxlExifReaderResult(null, null);
  }
}
