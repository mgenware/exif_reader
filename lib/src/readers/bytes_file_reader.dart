import 'dart:async';
import 'dart:typed_data';

import 'file_reader.dart';

/// A [FileReader] implementation for reading from a list of bytes.
class BytesFileReader implements FileReader {
  /// The bytes to read from.
  List<int> bytes;

  /// The current read position.
  int readPos = 0;

  /// Creates a [BytesFileReader] from a list of bytes.
  BytesFileReader(this.bytes);

  /// Returns the current read position in the byte list.
  @override
  Future<int> position() async {
    return readPos;
  }

  @override
  Future<List<int>> readAsBytes() async {
    return bytes;
  }

  /// Reads a single byte from the byte list.
  @override
  Future<int> readByte() async {
    return bytes[readPos++];
  }

  /// Reads [n] bytes from the byte list.
  ///
  /// Returns a [Uint8List] containing the bytes read.
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

  /// Sets the current read position in the byte list.
  @override
  Future<void> setPosition(int position) async {
    readPos = position;
  }
}
