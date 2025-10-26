import 'dart:async';
import 'dart:io';

import 'exif_types.dart';
import 'read_exif.dart';
import 'readers/file_reader.dart';

/// Reads EXIF metadata from a [File] object asynchronously.
///
/// This is a streaming version of [readExifFromBytes].
///
/// [file]: The image file to extract EXIF data from.
/// [stopTag]: Optional tag name to stop parsing at.
/// [details]: Whether to include detailed information (default: true).
/// [strict]: Whether to use strict parsing (default: false).
/// [debug]: Whether to enable debug output (default: false).
/// [truncateTags]: Whether to truncate long tag values (default: true).
///
/// Returns a map of tag names to [IfdTag] objects.
Future<Map<String, IfdTag>> readExifFromFile(
  File file, {
  String? stopTag,
  bool details = true,
  bool strict = false,
  bool debug = false,
  bool truncateTags = true,
}) async {
  final randomAccessFile = await file.open();
  try {
    final fileReader = await FileReader.fromFile(randomAccessFile);
    final r = await readExifFromFileReaderAsync(
      fileReader,
      stopTag: stopTag,
      details: details,
      strict: strict,
      debug: debug,
      truncateTags: truncateTags,
    );
    return r.tags;
  } finally {
    await randomAccessFile.close();
  }
}
