import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'file_reader.dart';

class RandomAccessFileReader implements FileReader {
  final RandomAccessFile file;

  RandomAccessFileReader(this.file);

  @override
  Future<int> position() async {
    return await file.position();
  }

  @override
  Future<List<int>> readAsBytes(bool fromStart) async {
    if (fromStart) {
      await file.setPosition(0);
    }
    final len = await file.length();
    final bytes = Uint8List(len);
    await file.readInto(bytes);
    return bytes;
  }

  @override
  Future<int> readByte() async {
    return await file.readByte();
  }

  @override
  Future<Uint8List> read(int bytes) async {
    return await file.read(bytes);
  }

  @override
  Future<void> setPosition(int position) async {
    await file.setPosition(position);
  }
}

Future<FileReader> createFileReaderFromFile(Object file) async {
  if (file is RandomAccessFile) {
    return RandomAccessFileReader(file);
  } else if (file is File) {
    final data = await file.readAsBytes();
    return FileReader.fromBytes(data);
  } else if (file is List<int>) {
    return FileReader.fromBytes(file);
  }
  throw UnsupportedError("Can't read file of type: ${file.runtimeType}");
}
