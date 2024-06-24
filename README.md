# exif_dart

[![Pub Package](https://img.shields.io/pub/v/exif_dart.svg)](https://pub.dev/packages/exif_dart)
[![Dart CI](https://github.com/mgenware/exif_dart/actions/workflows/dart.yml/badge.svg)](https://github.com/mgenware/exif_dart/actions/workflows/dart.yml)

Dart package to decode Exif data from TIFF, JPEG, HEIC, PNG and WebP files.

Fork of [exifdart](https://github.com/bigflood/dartexif)

## Usage

```dart
printExifOf(String path) async {

  final fileBytes = File(path).readAsBytesSync();
  final data = await readExifFromBytes(fileBytes);

  if (data.isEmpty) {
    print("No EXIF information found");
    return;
  }

  if (data.containsKey('JPEGThumbnail')) {
    print('File has JPEG thumbnail');
    data.remove('JPEGThumbnail');
  }
  if (data.containsKey('TIFFThumbnail')) {
    print('File has TIFF thumbnail');
    data.remove('TIFFThumbnail');
  }

  for (final entry in data.entries) {
    print("${entry.key}: ${entry.value}");
  }

}
```
