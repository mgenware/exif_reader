import 'dart:io';

import 'package:iso_base_media/iso_base_media.dart';

import 'makernote_canon.dart';
import 'read_exif.dart';
import 'reader.dart';
import 'tags.dart';
import 'tags_info.dart';
import 'util.dart';

class Cr3ExifReader {
  final RandomAccessFile raf;

  const Cr3ExifReader(this.raf);

  Future<List<ReadParams>> findExif() async {
    final res = <ReadParams>[];
    final fileBox = ISOBox.fileBoxFromRandomAccessFile(raf);
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
        final contentBox = ISOBox.fileBoxFromBytes(contentBytes);
        final exifBoxes = await contentBox
            .getDirectChildrenByTypes({'CMT1', 'CMT2', 'CMT3', 'CMT4'});
        for (final exifBox in exifBoxes) {
          final exifData = await exifBox.extractData();
          if (exifData.length <= 2) {
            continue;
          }
          final endian = Reader.endianOfByte(exifData[0]);
          Map<int, MakerTag>? tagDict;
          bool cr3MakerNote = false;
          if (exifBox.type == 'CMT3') {
            tagDict = MakerNoteCanon.tags;
            cr3MakerNote = true;
          } else if (exifBox.type == 'CMT4') {
            tagDict = StandardTags.gpsTags;
          }
          res.add(ReadParams(
            endian: endian,
            offset: 0,
            data: exifData,
            cr3MakerNote: cr3MakerNote,
            tagDict: tagDict,
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
