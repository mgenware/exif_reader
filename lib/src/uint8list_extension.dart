import 'dart:typed_data';

extension Uint8ListExt on Uint8List {
  Uint8List subView(int start, [int? end]) {
    return Uint8List.sublistView(this, start, end);
  }

  String toHex({String separator = ''}) {
    final StringBuffer buffer = StringBuffer();
    for (final byte in this) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
      if (separator.isNotEmpty) {
        buffer.write(separator);
      }
    }
    return buffer.toString();
  }

  ByteData asByteData([int offsetInBytes = 0, int? length]) {
    return ByteData.sublistView(this, offsetInBytes, length ?? lengthInBytes);
  }
}
