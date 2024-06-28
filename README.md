# exif_reader

[![pub package](https://img.shields.io/pub/v/exif_reader.svg)](https://pub.dev/packages/exif_reader)
[![Build Status](https://github.com/mgenware/exif_reader/workflows/Build/badge.svg)](https://github.com/mgenware/exif_reader/actions)

Dart package to decode Exif data from TIFF, JPEG, HEIC, PNG, WebP, JXL (JPEG XL) files. Fork of [exifdart](https://github.com/bigflood/dartexif).

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
