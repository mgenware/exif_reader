import 'dart:async';
import 'dart:typed_data';

import 'file_interface_generic.dart'
    if (dart.library.html) 'package:exif_reader/src/file_interface_html.dart'
    if (dart.library.io) 'package:exif_reader/src/file_interface_io.dart';

abstract class FileReader {
  static Future<FileReader> fromFile(dynamic file) async {
    return createFileReaderFromFile(file);
  }

  factory FileReader.fromBytes(List<int> bytes) {
    return _BytesReader(bytes);
  }

  Future<int> readByte();

  Future<Uint8List> read(int bytes);

  Future<int> position();

  Future<void> setPosition(int position);
}

class _BytesReader implements FileReader {
  List<int> bytes;
  int readPos = 0;

  _BytesReader(this.bytes);

  @override
  Future<int> position() async {
    return readPos;
  }

  @override
  Future<int> readByte() async {
    return bytes[readPos++];
  }

  @override
  Future<Uint8List> read(int n) async {
    final start = readPos;
    if (start >= bytes.length) {
      return Uint8List(0);
    }

    var end = readPos + n;
    if (end > bytes.length) {
      end = bytes.length;
    }
    final r = bytes.sublist(start, end);
    readPos += end - start;
    return Uint8List.fromList(r);
  }

  @override
  Future<void> setPosition(int position) async {
    readPos = position;
  }
}
