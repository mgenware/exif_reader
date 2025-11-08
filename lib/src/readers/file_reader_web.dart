import 'dart:async';
import 'dart:js_interop' as dart_js;
import 'dart:typed_data';

import 'package:js_interop_utils/js_interop_utils.dart';
import 'package:web/web.dart' as dart_web;

import 'file_reader.dart';

class RandomAccessFileReader implements FileReader {
  final Object file;

  RandomAccessFileReader(this.file);

  @override
  Future<int> position() => throw UnsupportedError(
      'RandomAccessFile is not supported on this platform.');

  @override
  Future<List<int>> readAsBytes(bool fromStart) => throw UnsupportedError(
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
  final jsFile = file.asJSObject;
  if (jsFile != null && jsFile.isA<dart_web.File>()) {
    final fileReader = dart_web.FileReader();
    fileReader.readAsArrayBuffer(file as dart_web.File);
    await fileReader.onLoadEnd.single;
    final data = fileReader.result;
    if (data != null && data.isA<dart_js.JSArrayBuffer>()) {
      return FileReader.fromBytes(
          (data as dart_js.JSArrayBuffer).toDart.asUint8List());
    }
  } else if (file is List<int>) {
    return FileReader.fromBytes(file);
  }
  throw UnsupportedError("Can't read file of type: ${file.runtimeType}");
}
