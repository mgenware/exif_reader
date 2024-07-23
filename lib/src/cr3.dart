import 'dart:io';

import 'package:iso_base_media/iso_base_media.dart';

import 'makernote_canon.dart';
import 'read_exif.dart';
import 'reader.dart';
import 'util.dart';

class Cr3ExifReader {
  final RandomAccessFile raf;

  const Cr3ExifReader(this.raf);

  Future<List<ReadParams>> findExif() async {
    final res = <ReadParams>[];
    final fileBox = ISOSourceBox.fromRandomAccessFile(raf);
    final moov = await fileBox.getDirectChildByTypes({'moov'});
    if (moov != null) {
      final uuidList = await moov.getDirectChildrenByTypes({'uuid'});
      for (final uuidBox in uuidList) {
        final data = await uuidBox.extractData();
        if (data.length < 17) {
          continue;
        }
        final first16Bytes = data.sublist(0, 16);
        final uuidString = uint8ListToHex(first16Bytes);
        if (uuidString != '85c0b687820f11e08111f4ce462b6a48') {
          continue;
        }
        final contentBytes = data.sublist(16);
        final contentBox = ISOSourceBox.fromBytes(contentBytes);
        final exifBoxes = await contentBox
            .getDirectChildrenByTypes({'CMT1', 'CMT2', 'CMT3', 'CMT4'});
        for (final exifBox in exifBoxes) {
          final exifData = await exifBox.extractData();
          if (exifData.length <= 2) {
            continue;
          }
          final endian = Reader.endianOfByte(exifData[0]);
          res.add(ReadParams(
            endian: endian,
            offset: 0,
            data: exifData,
            tagDict: exifBox.type == 'CMT3' ? MakerNoteCanon.tags : null,
            ifdNameCallback: (index) {
              switch (exifBox.type) {
                case 'CMT1':
                  return 'Image';
                case 'CMT2':
                  return 'EXIF';
                case 'CMT3':
                  return 'MakerNote';
                case 'CMT4':
                  return 'GPS';
                default:
                  return 'IFD $index';
              }
            },
          ));
        }

        // Found EXIF data.
        return res;
      }
    }
    return [];
  }
}
