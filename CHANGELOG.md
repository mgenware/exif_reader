## 3.12.1

- Ignore header case when parsing JXL EXIF boxes

## 3.12.0

- Add `GPSHPositioningError`.

## 3.11.0

- Handle iinf version when reading count
- Update `iso_base_media` to v4.0.0

## 3.10.0

- Return hex value in IfdBytes.toString

## 3.9.0

- Update Canon tags.

## 3.8.0

- Add support for RAF files.

## 3.7.1

- Fix brotli decoding issues

## 3.7.0

- Support JXL brob EXIF boxes

## 3.6.0

- Add support for JPEG XL EXIF (uncompressed)
- Migrate file IO to async functions

## 3.5.0

- Remove CLI
- Trim dependencies

## 3.4.0

- Add missing tags found in DNG files
- Add some JXL tags
- Support more compression values.

## 3.3.0

- Add WebP Support

## 3.2.1

- Add AVIF Support
- Add PNG Support

## 3.1.4

- Bump dependency `sprintf` to `7.0.0`
- Fix noop_primitive_operations

## 3.1.2

- Fix Bad state: No element while reading Exif

## 3.1.1

- Fixed range error issue
- Fixed some lint errors
- Changed file parameter type of readExifFromFile function from dynamic to io.File

## 3.0.1

- add time offset tag names
  - OffsetTime, OffsetTimeOriginal, OffsetTimeDigitized
- upgrade dependencies

## 3.0.0

- Breaking API Changes
  - Changed nullable type to non-nullable type if possible
  - Changed some parameters to camel-case
  - Added IfdValues and it's subtypes
  - IfdTag.values is now IfdValues type

## 2.2.0

- Add HEIC support

## 2.1.0

- fixed some minor issues

## 2.0.0

- migrate to null-safety
- change to MIT License

## 1.0.3

- Make package portable between Dart Web (dart:html dependent) and Dart Native (dart:io dependent)
- Upgraded Dart SDK to '>=2.0.0 <3.0.0'

## 1.0.2

- Add RandomAccessFile-backed reader

## 1.0.1

- bugfix: RangeError for some images

## 1.0.0

- Removed dependency on io package
- Removed readExifFromFile

## 0.1.5

- Added tests

## 0.1.2

- Initial version
