import 'dart:typed_data';

import 'package:random_access_source/random_access_source.dart';

import 'read_exif.dart';

/// Extracts EXIF tags and formats them as a readable string.
///
/// [bytes]: The image file bytes to extract EXIF data from.
/// [stopTag]: Optional tag name to stop parsing at.
/// [details]: Whether to include detailed information (default: true).
/// [strict]: Whether to use strict parsing (default: false).
/// [debug]: Whether to enable debug output (default: false).
/// [truncateTags]: Whether to truncate long tag values (default: true).
///
/// Returns a string with formatted EXIF tags and warnings, or a message if no EXIF data is found.
Future<String> printExifOfBytes(
  Uint8List bytes, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final data = await readExifFromSourceAsync(
    BytesRASource(bytes),
    stopTag: stopTag,
    details: details,
    strict: strict,
    debug: debug,
    truncateTags: truncateTags,
  );

  if (data.tags.isEmpty) {
    return 'No EXIF information found';
  }

  final prints = <String>[];

  // prints.addAll(data.warnings);

  if (data.tags.containsKey('JPEGThumbnail')) {
    prints.add('File has JPEG thumbnail');
    data.tags.remove('JPEGThumbnail');
  }
  if (data.tags.containsKey('TIFFThumbnail')) {
    prints.add('File has TIFF thumbnail');
    data.tags.remove('TIFFThumbnail');
  }

  final tagKeys = data.tags.keys.toList();
  tagKeys.sort();

  for (final key in tagKeys) {
    final tag = data.tags[key];
    prints.add('$key (${tag!.tagType}): $tag');
  }

  return prints.join('\n');
}
