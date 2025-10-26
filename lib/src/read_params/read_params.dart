import 'dart:typed_data';

import '../tags/maker_tags.dart';

/// Parameters for reading EXIF data from an image file.
class ReadParams {
  /// Whether to fake an EXIF beginning (used for some JPEGs).
  final bool fakeExif;

  /// Endianness of the EXIF data.
  final Endian endian;

  /// Offset to start reading EXIF data.
  final int offset;

  /// Error message, if any.
  final String error;

  /// If not null, use this data instead of the file.
  final List<int>? data;

  /// Callback to name IFDs by index.
  final String Function(int index)? ifdNameCallback;

  /// Optional tag dictionary for maker notes.
  final Map<int, MakerTag>? tagDict;

  /// Used to force parsing maker note of CMT3 section of CR3 files.
  final bool cr3MakerNote;

  /// Creates a [ReadParams] object for EXIF reading.
  ReadParams({
    required this.endian,
    required this.offset,
    this.fakeExif = false,
    this.data,
    this.ifdNameCallback,
    this.tagDict,
    this.cr3MakerNote = false,
  }) : error = '';

  /// Creates a [ReadParams] object representing an error.
  ReadParams.error(this.error)
      : endian = Endian.little,
        offset = 0,
        data = null,
        ifdNameCallback = null,
        tagDict = null,
        cr3MakerNote = false,
        fakeExif = false;
}
