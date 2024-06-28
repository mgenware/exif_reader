import 'dart:io';

import 'package:iso_base_media/iso_base_media.dart';

class JxlExifReader {
  final RandomAccessFile raf;

  const JxlExifReader(this.raf);

  Future<int?> findExif() async {
    final fileBox = await ISOFileBox.openRandomAccessFile(raf);
    ISOBox? child;
    do {
      child = await fileBox.nextChild();
      if (child != null) {
        if (child.type == 'Exif') {
          return child.dataOffset;
        }
      }
    } while (child != null);
    return null;
  }
}
