import 'dart:async';
import 'dart:typed_data';

import 'package:random_access_source/random_access_source.dart';

import 'exif_header.dart';
import 'exif_types.dart';
import 'makernotes/decode_makernote.dart';
import 'read_params/cr3/cr3.dart';
import 'read_params/heic/heic.dart';
import 'read_params/jpeg/jpeg.dart';
import 'read_params/jxl/jxl.dart';
import 'read_params/png/png.dart';
import 'read_params/raf/raf.dart';
import 'read_params/read_params.dart';
import 'read_params/tiff/tiff.dart';
import 'read_params/webp/webp.dart';
import 'readers/reader.dart';

/// Reads EXIF metadata from a byte array.
///
/// [bytes]: The image file data as a list of bytes.
/// [details]: Whether to include detailed information (default: true).
/// [strict]: Whether to use strict parsing (default: false).
/// [debug]: Whether to enable debug output (default: false).
/// [truncateTags]: Whether to truncate long tag values (default: true).
///
/// Returns an [ExifData] object containing parsed EXIF tags and warnings.
Future<ExifData> readExifFromBytes(
  Uint8List bytes, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final exif = await readExifFromSource(
    BytesRASource(bytes),
    stopTag: stopTag,
    details: details,
    strict: strict,
    debug: debug,
    truncateTags: truncateTags,
  );
  return exif;
}

/// Reads EXIF metadata from a source asynchronously.
///
/// [source]: A [RandomAccessSource], such as a file or byte array.
/// [details]: Whether to include detailed information (default: true).
/// [strict]: Whether to use strict parsing (default: false).
/// [debug]: Whether to enable debug output (default: false).
/// [truncateTags]: Whether to truncate long tag values (default: true).
///
/// Returns an [ExifData] object containing parsed EXIF tags and warnings.
Future<ExifData> readExifFromSource(
  RandomAccessSource src, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final List<ReadParams> readParamsList = [];

  // Determine file type.
  if (await src.length() < 12) {
    return ExifData.withWarning('File too small to contain EXIF data.');
  }
  final header = await src.read(12);
  if (TiffExifReader.isTiff(header)) {
    // TIFF
    final readParams = await TiffExifReader.readParams(src);
    readParamsList.add(readParams);
  } else if (HEICExifFinder.isHeif(header) || HEICExifFinder.isAvif(header)) {
    // HEIC
    final readParams = await HEICExifFinder.readParams(src);
    readParamsList.add(readParams);
  } else if (JpegExifReader.isJpeg(header)) {
    // JPEG
    final readParams = await JpegExifReader.readParams(src);
    readParamsList.add(readParams);
  } else if (PngExifReader.isPng(header)) {
    // PNG
    final readParams = await PngExifReader.readParams(src);
    readParamsList.add(readParams);
  } else if (WebpExifReader.isWebp(header)) {
    // WEBP
    final readParams = await WebpExifReader.readParams(src);
    readParamsList.add(readParams);
  } else if (JxlExifReader.isJxl(header)) {
    // JXL
    final readParams = await JxlExifReader.readParams(src);
    readParamsList.add(readParams);
  } else if (Cr3ExifReader.isCr3(header)) {
    // CR3
    final readParamList = await Cr3ExifReader.readParams(src);
    if (readParamList.isEmpty) {
      return ExifData.withWarning('No EXIF data found.');
    }
    readParamsList.addAll(readParamList);
  } else if (RafExifReader.isRaf(header)) {
    // RAF
    final readParams = await RafExifReader.readParams(src);
    readParamsList.add(readParams);
  } else {
    return ExifData.withWarning('File format not recognized.');
  }

  String err = '';
  for (final readParams in readParamsList) {
    if (readParams.error.isNotEmpty) {
      err += '${readParams.error}\n';
    }
  }
  if (err.isNotEmpty) {
    return ExifData.withWarning(err);
  }

  ExifData? exifData;
  for (final readParams in readParamsList) {
    final data = await _readExifFromReadParams(
      src: src,
      readParams: readParams,
      stopTag: stopTag,
      details: details,
      strict: strict,
      debug: debug,
      truncateTags: truncateTags,
    );
    exifData = (exifData == null) ? data : ExifData.merge(exifData, data);
  }

  return exifData ?? ExifData.withWarning('No EXIF information found.');
}

/// Internal helper to read EXIF data from [ReadParams].
///
/// [src] is the [RandomAccessSource] to read from.
/// [readParams] contains parameters for reading EXIF data.
/// [stopTag], [details], [strict], [debug], [truncateTags] control parsing behavior.
/// Returns an [ExifData] object.
Future<ExifData> _readExifFromReadParams({
  required RandomAccessSource src,
  required ReadParams readParams,
  required String? stopTag,
  required bool details,
  required bool strict,
  required bool debug,
  required bool truncateTags,
}) async {
  final file = IfdReader(
    BinaryReader(
        (readParams.data != null) ? BytesRASource(readParams.data!) : src,
        readParams.offset,
        readParams.endian),
    fakeExif: readParams.fakeExif,
  );

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
    await hdr.dumpIfd(
        ifd,
        readParams.ifdNameCallback != null
            ? readParams.ifdNameCallback!(ifdIndex)
            : _ifdNameOfIndex(ifdIndex),
        tagDict: readParams.tagDict,
        stopTag: stopTag);
  }
  if (readParams.cr3MakerNote) {
    DecodeMakerNote.postProcessCanonTags(hdr.tags);
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

  return ExifData(
    hdr.tags.map((key, value) => MapEntry(key, value.tag)),
    hdr.warnings,
  );
}

/// Returns the name of the IFD (Image File Directory) for a given index.
String _ifdNameOfIndex(int index) {
  if (index == 0) {
    return 'Image';
  } else if (index == 1) {
    return 'Thumbnail';
  } else {
    return 'IFD $index';
  }
}
