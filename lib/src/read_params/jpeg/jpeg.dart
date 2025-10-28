import 'dart:typed_data';

import '../../helpers/util.dart';
import '../../readers/file_reader.dart' show FileReader;
import '../../readers/reader.dart' show Reader;
import '../read_params.dart';

class JpegExifReader {
  // Returns true if the header indicates a JPEG file.
  static bool isJpeg(List<int> header) {
    return listRangeEqual(header, 0, 2, '\xFF\xD8'.codeUnits);
  }

  /// Reads JPEG EXIF parameters from a [FileReader].
  /// Returns a [ReadParams] object or error.
  static Future<ReadParams> readParams(FileReader f) async {
    // by default do not fake an EXIF beginning
    var fakeExif = false;
    int offset;
    Endian endian;

    await f.setPosition(0);

    const headerLength = 12;
    final rawData = await f.read(headerLength);
    var data = List<int>.from(rawData);
    if (data.length != headerLength) {
      return ReadParams.error('File format not recognized.');
    }

    var base = 2;
    while (data[2] == 0xFF &&
        listContainedIn(data.sublist(6, 10), [
          'JFIF'.codeUnits,
          'JFXX'.codeUnits,
          'OLYM'.codeUnits,
          'Phot'.codeUnits,
        ])) {
      final length = data[4] * 256 + data[5];
      await f.read(length - 8);
      data = [0xFF, 0x00];
      data.addAll(await f.read(10));
      fakeExif = true;
      if (base > 2) {
        base = base + length + 4 - 2;
      } else {
        base = length + 4;
      }
    }

    // Patch to deal with APP2 (or other) data before APP1
    await f.setPosition(0);
    data = await f.read(base + 4000);

    while (true) {
      if (listRangeEqual(data, base, base + 2, [0xFF, 0xE1])) {
        // APP1
        if (listRangeEqual(data, base + 4, base + 8, 'Exif'.codeUnits)) {
          base -= 2;
          break;
        }
        base += _incrementBase(data, base);
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE0])) {
        // APP0
        base += _incrementBase(data, base);
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE2])) {
        // APP2
        base += _incrementBase(data, base);
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xEE])) {
        // APP14
        // printf("**  APP14 Adobe segment at base 0x%X", [base]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
        base += _incrementBase(data, base);
        // print("**  There is useful EXIF-like data here, but we have no parser for it.");
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xDB])) {
        // printf("**  JPEG image data at base 0x%X No more segments are expected.", [base]);
        break;
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xD8])) {
        // APP12
        // printf("**  FFD8 segment at base 0x%X", [base]);
        // printf("**  Got 0x%X 0x%X and %s instead", [data[base], data[base + 1], data.sublist(4 + base,10 + base)]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
        base += _incrementBase(data, base);
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xEC])) {
        // APP12
        // printf("**  APP12 XMP (Ducky) or Pictureinfo segment at base 0x%X", [base]);
        // printf("**  Got 0x%X and 0x%X instead", [data[base], data[base + 1]]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
        base += _incrementBase(data, base);
        // print("**  There is useful EXIF-like data here (quality, comment, copyright), but we have no parser for it.");
      } else {
        try {
          base += _incrementBase(data, base);
        } on RangeError {
          return ReadParams.error(
            'Unexpected/unhandled segment type or file content.',
          );
        }
      }
    }

    await f.setPosition(base + 12);
    if (data[2 + base] == 0xFF &&
        listRangeEqual(data, 6 + base, 10 + base, 'Exif'.codeUnits)) {
      // detected EXIF header
      offset = await f.position();
      endian = Reader.endianOfByte(await f.readByte());
      //HACK TEST:  endian = 'M'
    } else if (data[2 + base] == 0xFF &&
        listRangeEqual(data, 6 + base, 10 + base + 1, 'Ducky'.codeUnits)) {
      // detected Ducky header.
      // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      offset = await f.position();
      endian = Reader.endianOfByte(await f.readByte());
    } else if (data[2 + base] == 0xFF &&
        listRangeEqual(data, 6 + base, 10 + base + 1, 'Adobe'.codeUnits)) {
      // detected APP14 (Adobe);
      // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      offset = await f.position();
      endian = Reader.endianOfByte(await f.readByte());
    } else {
      // print("** No EXIF header expected data[2+base]==0xFF and data[6+base:10+base]===Exif (or Duck)");
      // printf("** Did get 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      return ReadParams.error('No EXIF information found');
    }

    return ReadParams(endian: endian, offset: offset, fakeExif: fakeExif);
  }

  /// Calculates the next segment base offset in JPEG/EXIF data.
  ///
  /// [data] is the byte list of the image.
  /// [base] is the current base offset.
  /// Returns the next base offset.
  static int _incrementBase(List<int> data, int base) {
    return (data[base + 2]) * 256 + (data[base + 3]) + 2;
  }
}
