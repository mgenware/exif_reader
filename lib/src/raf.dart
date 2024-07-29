import 'dart:convert';
import 'dart:io';

import 'read_exif.dart';
import 'reader.dart';

final _exifHeader = AsciiCodec().decode([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]);

class RafExifReader {
  final File file;

  const RafExifReader(this.file);

  Future<ReadParams?> findExif() async {
    final bytes = await file.readAsBytes();
    final asciiString = AsciiCodec().decode(bytes, allowInvalid: true);
    final index = asciiString.indexOf(_exifHeader);
    if (index == -1) {
      return null;
    }
    // Get the staring position of the Exif data.
    final exifStart = index + _exifHeader.length;
    if (exifStart + 2 >= bytes.length) {
      return null;
    }
    final endianByte = bytes[exifStart];
    final endian = Reader.endianOfByte(endianByte);
    return ReadParams(
      offset: exifStart,
      endian: endian,
    );
  }
}
