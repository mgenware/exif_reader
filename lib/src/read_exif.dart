import 'dart:async';

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
import 'readers/bytes_file_reader.dart';
import 'readers/file_reader.dart';
import 'readers/reader.dart';

/// Reads EXIF metadata from a byte array.
///
/// [bytes]: The image file data as a list of bytes.
/// [stopTag]: Optional tag name to stop parsing at.
/// [details]: Whether to include detailed information (default: true).
/// [strict]: Whether to use strict parsing (default: false).
/// [debug]: Whether to enable debug output (default: false).
/// [truncateTags]: Whether to truncate long tag values (default: true).
///
/// Returns a map of tag names to [IfdTag] objects.
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

/// Reads EXIF metadata from a [FileReader] object asynchronously.
///
/// Parses EXIF tags and warnings from the given [FileReader].
///
/// [fileReader]: The file reader for the image file.
/// [stopTag]: Optional tag name to stop parsing at.
/// [details]: Whether to include detailed information (default: true).
/// [strict]: Whether to use strict parsing (default: false).
/// [debug]: Whether to enable debug output (default: false).
/// [truncateTags]: Whether to truncate long tag values (default: true).
///
/// Returns an [ExifData] object containing parsed EXIF tags and warnings.
Future<ExifData> readExifFromFileReaderAsync(
  FileReader fileReader, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final List<ReadParams> readParamsList = [];

  // Determine file type
  final header = await fileReader.read(12);
  if (TiffExifReader.isTiff(header)) {
    // TIFF
    final readParams = await TiffExifReader.readParams(fileReader);
    readParamsList.add(readParams);
  } else if (HEICExifFinder.isHeif(header) || HEICExifFinder.isAvif(header)) {
    // HEIC
    final readParams = await HEICExifFinder.readParams(fileReader);
    readParamsList.add(readParams);
  } else if (JpegExifReader.isJpeg(header)) {
    // JPEG
    final readParams = await JpegExifReader.readParams(fileReader);
    readParamsList.add(readParams);
  } else if (PngExifReader.isPng(header)) {
    // PNG
    final readParams = await PngExifReader.readParams(fileReader);
    readParamsList.add(readParams);
  } else if (WebpExifReader.isWebp(header)) {
    // WEBP
    final readParams = await WebpExifReader.readParams(fileReader);
    readParamsList.add(readParams);
  } else if (JxlExifReader.isJxl(header)) {
    // JXL
    final readParams = await JxlExifReader.readParams(fileReader);
    readParamsList.add(readParams);
  } else if (Cr3ExifReader.isCr3(header)) {
    // CR3
    final readParamList = await Cr3ExifReader.readParams(fileReader);
    if (readParamList.isEmpty) {
      return ExifData.withWarning('No EXIF data found.');
    }
    readParamsList.addAll(readParamList);
  } else if (RafExifReader.isRaf(header)) {
    // RAF
    final readParams = await RafExifReader.readParams(fileReader);
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
      fileReader: fileReader,
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
/// [fileReader] is the file reader for the image file.
/// [readParams] contains parameters for reading EXIF data.
/// [stopTag], [details], [strict], [debug], [truncateTags] control parsing behavior.
/// Returns an [ExifData] object.
Future<ExifData> _readExifFromReadParams({
  required FileReader fileReader,
  required ReadParams readParams,
  required String? stopTag,
  required bool details,
  required bool strict,
  required bool debug,
  required bool truncateTags,
}) async {
  final reader = (readParams.data != null)
      ? BytesFileReader(readParams.data!)
      : fileReader;
  final file = IfdReader(
    Reader(reader, readParams.offset, readParams.endian),
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
