import 'dart:async';
import 'dart:typed_data';

import 'bytes_file_reader.dart';
import 'file_reader_generic.dart'
    if (dart.library.js_interop) 'file_reader_web.dart'
    if (dart.library.io) 'file_reader_vm.dart' as impl_;

/// An abstract interface for reading files in EXIF reader implementations.
abstract class FileReader {
  /// Creates a [FileReader] from a file object.
  ///
  /// [file]: The file object to read from.
  static Future<FileReader> fromFile(Object file) async {
    return impl_.createFileReaderFromFile(file);
  }

  /// Creates a [FileReader] from a list of bytes.
  ///
  /// [bytes]: The bytes to read from.
  factory FileReader.fromBytes(List<int> bytes) {
    return BytesFileReader(bytes);
  }

  Future<List<int>> readAsBytes(bool fromStart);

  /// Reads a single byte from the file.
  Future<int> readByte();

  /// Reads a specified number of bytes from the file.
  ///
  /// [bytes]: The number of bytes to read.
  Future<Uint8List> read(int bytes);

  /// Returns the current read position in the file.
  Future<int> position();

  /// Sets the current read position in the file.
  ///
  /// [position]: The position to set.
  Future<void> setPosition(int position);
}

typedef RandomAccessFileReader = impl_.RandomAccessFileReader;
