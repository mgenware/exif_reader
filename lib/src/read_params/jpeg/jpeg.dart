import 'dart:typed_data';

import 'package:jpeg_markers/jpeg_markers.dart';
import 'package:random_access_source/random_access_source.dart';

import '../../helpers/util.dart';
import '../../readers/reader.dart' show BinaryReader;
import '../read_params.dart';

final _exifSig = 'Exif\x00\x00'.codeUnits;

class JpegExifReader {
  static bool isJpeg(List<int> header) {
    return listRangeEqual(header, 0, 2, '\xFF\xD8'.codeUnits);
  }

  static Future<ReadParams?> readParams(RandomAccessSource src) async {
    await src.seek(0);
    final imgBytes = await src.readToEnd();

    Uint8List? exifData;
    scanJpegMarkers(imgBytes, (marker, offset) {
      if (marker.type == 0xE1) {
        final content = _markerContent(marker, offset, imgBytes);
        if (bytesStartWith(content, _exifSig)) {
          exifData = Uint8List.sublistView(content, _exifSig.length);
          return false;
        }
      }
      return true;
    });
    if (exifData == null || exifData!.length < 2) {
      return null;
    }
    final endian = BinaryReader.endianOfByte(exifData![0]);
    return ReadParams(endian: endian, data: exifData, offset: 0);
  }
}

Uint8List _markerContent(JpegMarker marker, int offset, Uint8List bytes) {
  final contentStart = offset + 4;
  final contentEnd = contentStart + marker.contentLength;
  final content = Uint8List.sublistView(bytes, contentStart, contentEnd);
  return content;
}
