import 'dart:async';
import 'dart:typed_data';

import 'file_reader.dart';

class RandomAccessFileReader implements FileReader {
  final Object file;

  RandomAccessFileReader(this.file);

  @override
  Future<int> position() => throw UnsupportedError(
      'RandomAccessFile is not supported on this platform.');

  @override
  Future<List<int>> readAsBytes() => throw UnsupportedError(
      'RandomAccessFile is not supported on this platform.');

  @override
  Future<int> readByte() => throw UnsupportedError(
      'RandomAccessFile is not supported on this platform.');

  @override
  Future<Uint8List> read(int bytes) => throw UnsupportedError(
      'RandomAccessFile is not supported on this platform.');

  @override
  Future<void> setPosition(int position) => throw UnsupportedError(
      'RandomAccessFile is not supported on this platform.');
}

Future<FileReader> createFileReaderFromFile(Object file) async {
  if (file is List<int>) {
    return FileReader.fromBytes(file);
  }
  throw UnsupportedError("Can't read file of type: ${file.runtimeType}");
}
