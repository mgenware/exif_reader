# exif_reader

[![pub package](https://img.shields.io/pub/v/exif_reader.svg)](https://pub.dev/packages/exif_reader)
[![Build Status](https://github.com/mgenware/exif_reader/workflows/Dart/badge.svg)](https://github.com/mgenware/exif_reader/actions)

Dart package to decode EXIF data from TIFF, JPEG, HEIC, AVIF, PNG, WebP, JXL (JPEG XL), ARW, RAW, DNG, CRW, CR3, NRW, NEF, RAF files. Fork of [exifdart](https://github.com/bigflood/dartexif).

## Example

```dart
final exif =
    await readExifFromBytes(bytes);

if (exif.warnings.isNotEmpty) {
  print('Warnings:');
  for (final warning in exif.warnings) {
    print('  $warning');
  }
}

if (exif.tags.isEmpty) {
  print('No EXIF information found');
  return;
}

for (final entry in exif.tags.entries) {
  print('${entry.key}: ${entry.value}');
}
```

## Usage

There are 2 ways to read EXIF data:

### `readExifFromBytes`

This reads EXIF from a list of bytes `Uint8List`.

### `readExifFromSource`

This reads EXIF from a `RandomAccessSource`. To use this type, you should install the [random_access_source](https://github.com/flutter-cavalry/random_access_source) package as well.

```sh
# Dart
dart pub add random_access_source
# Or Flutter
flutter pub add random_access_source
```

To create a `RandomAccessSource`, use the following implementations:

- Use `BytesRASource` for `Uint8List`.
  - `BytesRASource(Uint8List bytes)`: creates a `BytesRASource` from the given `bytes`.
- Use `FileRASource` for `File` (`dart:io`) and `Blob` (`package:web`).
  - `await FileRASource.open(path)`: Opens a `FileRASource` from a file path.
  - `await FileRASource.load(file)`: Loads a `FileRASource` from a `PlatformFile`.

### `ExifData`

The result value of both methods above is `ExifData`.

```dart
/// Represents the extracted EXIF data, including tags and warnings.
class ExifData {
  /// The map of tag names to [IfdTag] objects.
  final Map<String, IfdTag> tags;

  /// List of warnings encountered during EXIF extraction.
  final List<String> warnings;
}
```
