# exif_reader

[![pub package](https://img.shields.io/pub/v/exif_reader.svg)](https://pub.dev/packages/exif_reader)
[![Build Status](https://github.com/mgenware/exif_reader/workflows/Dart/badge.svg)](https://github.com/mgenware/exif_reader/actions)

Dart package to decode EXIF data from TIFF, JPEG, HEIC, PNG, WebP, JXL (JPEG XL), ARW, RAW, DNG, CRW, CR3, NRW, NEF files. Fork of [exifdart](https://github.com/bigflood/dartexif).

## Usage

```dart
Future<void> main(List<String> arguments) async {
  for (final filename in arguments) {
    print('Reading $filename ..');

    final data = await readExifFromFile(File(filename));

    if (data.isEmpty) {
      print('No EXIF information found');
      return;
    }

    for (final entry in data.entries) {
      print('${entry.key}: ${entry.value}');
    }
  }
}
```
