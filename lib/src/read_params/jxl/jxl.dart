import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:iso_base_media/iso_base_media.dart';
import 'package:random_access_source/random_access_source.dart';

import '../../helpers/util.dart';
import '../../readers/reader.dart' show BinaryReader;
import '../read_params.dart';

class JxlExifReaderResult {
  final int? exifOffset;
  // Not null if exif data is compressed.
  // If exif data is not compressed, only [exifOffset] is set.
  final Uint8List? exifData;

  JxlExifReaderResult(this.exifOffset, this.exifData);
}

class JxlExifReader {
  static bool isJxl(List<int> header) => listRangeEqual(
        header,
        0,
        12,
        [
          0x00,
          0x00,
          0x00,
          0x0C,
          0x4A,
          0x58,
          0x4C,
          0x20,
          0x0D,
          0x0A,
          0x87,
          0x0A
        ],
      );

  static Future<ReadParams> readParams(RandomAccessSource src) async {
    final res = await _findExif(src);
    if (res.exifData != null && res.exifData!.isNotEmpty) {
      final endian = BinaryReader.endianOfByte(res.exifData![0]);
      return ReadParams(endian: endian, data: res.exifData, offset: 0);
    }
    if (res.exifOffset == null) {
      return ReadParams.error('No exif found');
    }
    final offset = res.exifOffset!;
    final endianByte = await src.readByte();
    final endian = BinaryReader.endianOfByte(endianByte);
    return ReadParams(endian: endian, offset: offset);
  }

  static Future<JxlExifReaderResult> _findExif(RandomAccessSource src) async {
    final fileBox = ISOBox.createRootBox();
    ISOBox? child;
    do {
      child = await fileBox.nextChild(src);
      if (child != null) {
        if (child.type.toLowerCase() == 'exif') {
          return JxlExifReaderResult(
              child.dataOffset
                  // Skip full box flag.
                  // https://github.com/libjxl/libjxl/issues/3236
                  +
                  4,
              null);
        } else if (child.type == 'brob') {
          final boxBytes = await child.extractData(src);
          final header = boxBytes.sublist(0, 4);
          final headerString = String.fromCharCodes(header);
          if (headerString.toLowerCase() == 'exif') {
            // Skip to 'Exif' header (which is compressed and right before compressed data).
            final brotliBytes = boxBytes.sublist(4);
            final decodedBytes = brotli.decode(brotliBytes);
            return JxlExifReaderResult(
                null,
                // Skip full box flag.
                // https://github.com/libjxl/libjxl/issues/3236
                Uint8List.fromList(decodedBytes.sublist(4)));
          }
        }
      }
    } while (child != null);
    return JxlExifReaderResult(null, null);
  }
}
