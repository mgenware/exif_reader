import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'exif_decode_makernote.dart';
import 'exif_types.dart';
import 'exifheader.dart';
import 'file_interface.dart';
import 'file_interface_io.dart';
import 'heic.dart';
import 'jxl.dart';
import 'linereader.dart';
import 'reader.dart';
import 'util.dart';

int _incrementBase(List<int> data, int base) {
  return (data[base + 2]) * 256 + (data[base + 3]) + 2;
}

/// Process an image file data.
/// This is the function that has to deal with all the arbitrary nasty bits
/// of the EXIF standard.
Future<Map<String, IfdTag>> readExifFromBytes(
  List<int> bytes, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final exif = await readExifFromFileReaderAsync(
    FileReader.fromBytes(bytes),
    stopTag: stopTag,
    details: details,
    strict: strict,
    debug: debug,
    truncateTags: truncateTags,
  );
  return exif.tags;
}

/// Streaming version of [readExifFromBytes].
Future<Map<String, IfdTag>> readExifFromFile(
  File file, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final randomAccessFile = await file.open();
  final fileReader = await FileReader.fromFile(randomAccessFile);
  final r = await readExifFromFileReaderAsync(
    fileReader,
    stopTag: stopTag,
    details: details,
    strict: strict,
    debug: debug,
    truncateTags: truncateTags,
  );
  await randomAccessFile.close();
  return r.tags;
}

/// Process an image file (expects an open file object).
/// This is the function that has to deal with all the arbitrary nasty bits
/// of the EXIF standard.
Future<ExifData> readExifFromFileReaderAsync(
  FileReader f, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  ReadParams readParams;

  // determine whether it's a JPEG or TIFF
  final header = await f.read(12);
  if (_isTiff(header)) {
    readParams = await _tiffReadParams(f);
  } else if (_isHeic(header) || _isAvif(header)) {
    readParams = await _heicReadParams(f);
  } else if (_isJpeg(header)) {
    readParams = await _jpegReadParams(f);
  } else if (_isPng(header)) {
    readParams = await _pngReadParams(f);
  } else if (_isWebp(header)) {
    readParams = await _webpReadParams(f);
  } else if (_isJxl(header)) {
    readParams = await _jxlReadParams(f);
  } else {
    return ExifData.withWarning('File format not recognized.');
  }

  if (readParams.error != '') {
    return ExifData.withWarning(readParams.error);
  }

  IfdReader file;
  if (readParams.data != null) {
    file = IfdReader(
      Reader(BytesFileReader(readParams.data!), readParams.offset,
          readParams.endian),
      fakeExif: readParams.fakeExif,
    );
  } else {
    file = IfdReader(
      Reader(f, readParams.offset, readParams.endian),
      fakeExif: readParams.fakeExif,
    );
  }

  final hdr = ExifHeader(
    file: file,
    strict: strict,
    debug: debug,
    detailed: details,
    truncateTags: truncateTags,
  );

  final ifdList = await file.listIfd();

  for (int ifdIndex = 0; ifdIndex < ifdList.length; ifdIndex++) {
    final ifd = ifdList[ifdIndex];
    await hdr.dumpIfd(ifd, _ifdNameOfIndex(ifdIndex), stopTag: stopTag);
  }

  // EXIF IFD
  final exifOff = hdr.tags['Image ExifOffset'];
  if (exifOff != null && exifOff.tag.values is IfdInts) {
    await hdr.dumpIfd(
      exifOff.tag.values.firstAsInt(),
      'EXIF',
      stopTag: stopTag,
    );
  }

  if (details) {
    await DecodeMakerNote(hdr.tags, hdr.file, hdr.dumpIfd).decode();
  }

  if (details && ifdList.length >= 2) {
    await hdr.extractTiffThumbnail(ifdList[1]);
    await hdr.extractJpegThumbnail();
  }

  // parse XMP tags (experimental)
  if (debug && details) {
    await _parseXmpTags(f, hdr);
  }

  return ExifData(
    hdr.tags.map((key, value) => MapEntry(key, value.tag)),
    hdr.warnings,
  );
}

String _ifdNameOfIndex(int index) {
  if (index == 0) {
    return 'Image';
  } else if (index == 1) {
    return 'Thumbnail';
  } else {
    return 'IFD $index';
  }
}

Future<void> _parseXmpTags(FileReader f, ExifHeader hdr) async {
  String xmpString = '';
  // Easy we already have them
  final imageApplicationNotes = hdr.tags['Image ApplicationNotes'];
  if (imageApplicationNotes != null) {
    // XMP present in Exif
    final tag = imageApplicationNotes.tag;
    xmpString =
        (tag is IfdInts) ? makeString((tag as IfdInts).ints) : tag.toString();
    // We need to look in the entire file for the XML
  } else {
    // XMP not in Exif, searching file for XMP info...
    bool xmlStarted = false;
    bool xmlFinished = false;
    final reader = LineReader(f);
    while (true) {
      String line = await reader.readLine();
      if (line.isEmpty) {
        break;
      }

      final openTag = line.indexOf('<x:xmpmeta');
      final closeTag = line.indexOf('</x:xmpmeta>');

      if (openTag != -1) {
        xmlStarted = true;
        line = line.substring(openTag);
        // printf('** XMP found opening tag at line position %s', [open_tag]);
      }

      if (closeTag != -1) {
        // printf('** XMP found closing tag at line position %s', [close_tag]);
        int lineOffset = 0;
        if (openTag != -1) {
          lineOffset = openTag;
        }
        line = line.substring(0, (closeTag - lineOffset) + 12);
        xmlFinished = true;
      }

      if (xmlStarted) {
        xmpString += line;
      }

      if (xmlFinished) {
        break;
      }
    }

    // print('** XMP Finished searching for info');
    if (xmpString.isNotEmpty) {
      hdr.parseXmp(xmpString);
    }
  }
}

bool _isTiff(List<int> header) =>
    header.length >= 4 &&
    listContainedIn(
      header.sublist(0, 4),
      ['II*\x00'.codeUnits, 'MM\x00*'.codeUnits],
    );

bool _isHeic(List<int> header) =>
    listRangeEqual(header, 4, 12, 'ftypheic'.codeUnits);

bool _isAvif(List<int> header) =>
    listRangeEqual(header, 4, 12, 'ftypavif'.codeUnits);

bool _isJxl(List<int> header) => listRangeEqual(
      header,
      0,
      12,
      [0x00, 0x00, 0x00, 0x0C, 0x4A, 0x58, 0x4C, 0x20, 0x0D, 0x0A, 0x87, 0x0A],
    );

bool _isJpeg(List<int> header) =>
    listRangeEqual(header, 0, 2, '\xFF\xD8'.codeUnits);

bool _isPng(List<int> header) =>
    listRangeEqual(header, 0, 8, '\x89PNG\r\n\x1a\n'.codeUnits);

bool _isWebp(List<int> header) =>
    listRangeEqual(header, 0, 4, 'RIFF'.codeUnits) &&
    listRangeEqual(header, 8, 12, 'WEBP'.codeUnits);

Future<ReadParams> _heicReadParams(FileReader f) async {
  await f.setPosition(0);
  final heic = HEICExifFinder(f);
  final res = await heic.findExif();
  if (res.length != 2) {
    return ReadParams.error('Possibly corrupted heic data');
  }
  final int offset = res[0];
  final Endian endian = Reader.endianOfByte(res[1]);
  return ReadParams(endian: endian, offset: offset);
}

Future<ReadParams> _jxlReadParams(FileReader f) async {
  if (f is RafFileReader) {
    final jxlReader = JxlExifReader(f.file);
    final res = await jxlReader.findExif();
    if (res.exifData != null && res.exifData!.isNotEmpty) {
      final endian = Reader.endianOfByte(res.exifData![0]);
      return ReadParams(endian: endian, data: res.exifData, offset: 0);
    }
    if (res.exifOffset == null) {
      return ReadParams.error('No exif found');
    }
    final offset = res.exifOffset!;
    final endianByte = await f.readByte();
    final endian = Reader.endianOfByte(endianByte);
    return ReadParams(endian: endian, offset: offset);
  }
  throw Exception('JXL bytes reader is not supported yet.');
}

Future<ReadParams> _jpegReadParams(FileReader f) async {
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
    // printf("** Length offset is %d", [length]);
    await f.read(length - 8);
    // fake an EXIF beginning of file
    // I don't think this is used. --gd
    data = [0xFF, 0x00];
    data.addAll(await f.read(10));
    fakeExif = true;
    if (base > 2) {
      // print("** Added to base");
      base = base + length + 4 - 2;
    } else {
      // print("** Added to zero");
      base = length + 4;
    }
    // printf("** Set segment base to 0x%X", [base]);
  }

  // Big ugly patch to deal with APP2 (or other) data coming before APP1
  await f.setPosition(0);
  // in theory, this could be insufficient since 64K is the maximum size--gd
  // print('** f.position=${f.positionSync()}, base=$base');
  data = await f.read(base + 4000);
  // print('** data.length=${data.length}');

  // base = 2
  while (true) {
    // print('** base=$base');

    // if (data.length == 4020) {
    //   print("**  data.length=${data.length}, base=$base");
    // }
    if (listRangeEqual(data, base, base + 2, [0xFF, 0xE1])) {
      // APP1
      // print("**   APP1 at base $base");
      // print("**   Length: (${data[base + 2]}, ${data[base + 3]})");
      // print("**   Code: ${new String.fromCharCodes(data.sublist(base + 4,base + 8))}");
      if (listRangeEqual(data, base + 4, base + 8, 'Exif'.codeUnits)) {
        // print("**  Decrement base by 2 to get to pre-segment header (for compatibility with later code)");
        base -= 2;
        break;
      }
      base += _incrementBase(data, base);
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE0])) {
      // APP0
      // print("**  APP0 at base $base");
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("**  Code: %s", [data.sublist(base + 4, base + 8)]);
      base += _incrementBase(data, base);
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE2])) {
      // APP2
      // printf("**  APP2 at base 0x%X", [base]);
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
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

Future<ReadParams> _pngReadParams(FileReader f) async {
  await f.setPosition(8);
  while (true) {
    final data = await f.read(8);
    final chunk = String.fromCharCodes(data.sublist(4, 8));

    if (chunk.isEmpty || chunk == 'IEND') {
      break;
    }
    if (chunk == 'eXIf') {
      final offset = await f.position();
      final endian = Reader.endianOfByte(await f.readByte());
      return ReadParams(endian: endian, offset: offset);
    }

    final chunkSize =
        Int8List.fromList(data.sublist(0, 4)).buffer.asByteData().getInt32(0);
    await f.setPosition(await f.position() + chunkSize + 4);
  }

  return ReadParams.error('No EXIF information found');
}

Future<ReadParams> _webpReadParams(FileReader f) async {
  // Each RIFF box is a 4-byte ASCII tag, followed by a little-endian uint32
  // length, and  finally that number of bytes of data. The file starts with an
  // outer box with the tag 'RIFF', whose content is the file format ('WEBP')
  // followed by a series of inner boxes. We need the inner 'EXIF' box.
  //
  // The outer box encapsulates the entire file, so we can safely skip forward
  // to the first inner box.
  await f.setPosition(12);
  while (true) {
    final header = await f.read(8);
    if (header.isEmpty) {
      return ReadParams.error('No EXIF information found');
    } else if (header.length < 8) {
      return ReadParams.error('Invalid RIFF encoding');
    }

    final tag = String.fromCharCodes(header.sublist(0, 4));
    final length = Int8List.fromList(header.sublist(4, 8))
        .buffer
        .asByteData()
        .getInt32(0, Endian.little);

    // According to exiftool's RIFF documentation, WebP uses "EXIF" as tag
    // name while other RIFF-based files tend to use "Exif".
    if (tag == 'EXIF') {
      // Look for Exif\x00\x00, and skip it if present. The WebP implementation
      // in Exiv2 also handles a \xFF\x01\xFF\xE1\x00\x00 prefix, but with no
      // explanation or test file present, so we ignore that for now.
      final exifHeader = await f.read(6);
      if (!listEqual(
        exifHeader,
        Uint8List.fromList('Exif\x00\x00'.codeUnits),
      )) {
        // There was no Exif\x00\x00 marker, rewind
        await f.setPosition(await f.position() - exifHeader.length);
      }

      final offset = await f.position();
      final endian = Reader.endianOfByte(await f.readByte());
      return ReadParams(endian: endian, offset: offset);
    }

    // Skip forward to the next box.
    await f.setPosition(await f.position() + length);
  }
}

Future<ReadParams> _tiffReadParams(FileReader f) async {
  await f.setPosition(0);
  final endian = Reader.endianOfByte(await f.readByte());
  await f.read(1);
  return ReadParams(endian: endian, offset: 0);
}

class ReadParams {
  final bool fakeExif;
  final Endian endian;
  final int offset;
  final String error;
  final List<int>? data;

  ReadParams({
    required this.endian,
    required this.offset,
    // by default do not fake an EXIF beginning
    this.fakeExif = false,
    this.data,
  }) : error = '';

  ReadParams.error(this.error)
      : endian = Endian.little,
        offset = 0,
        data = null,
        fakeExif = false;
}
