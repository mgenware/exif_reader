import 'dart:io';
import 'dart:typed_data';

import 'read_exif.dart';
import 'reader.dart';

class RafExifReader {
  final RandomAccessFile raf;

  const RafExifReader(this.raf);

  Future<ReadParams?> findExif() async {}
}

// https://stackoverflow.com/questions/65194980/search-for-sequence-in-uint8list
extension IndexOfElements<T> on List<T> {
  int indexOfElements(List<T> elements, [int start = 0]) {
    if (elements.isEmpty) return start;
    var end = length - elements.length;
    if (start > end) return -1;
    var first = elements.first;
    var pos = start;
    while (true) {
      pos = indexOf(first, pos);
      if (pos < 0 || pos > end) return -1;
      for (var i = 1; i < elements.length; i++) {
        if (this[pos + i] != elements[i]) {
          pos++;
          continue;
        }
      }
      return pos;
    }
  }
}
