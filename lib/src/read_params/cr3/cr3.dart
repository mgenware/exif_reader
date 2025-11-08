import 'package:iso_base_media/iso_base_media.dart';
import 'package:random_access_source/random_access_source.dart';

import '../../helpers/uint8list_extension.dart';
import '../../helpers/util.dart';
import '../../makernotes/makernote_canon.dart' as canon_;
import '../../readers/reader.dart';
import '../../tags/maker_tags.dart';
import '../../tags/standard_tags.dart';
import '../read_params.dart';

class Cr3ExifReader {
  static bool isCr3(List<int> header) =>
      listRangeEqual(header, 4, 12, 'ftypcrx '.codeUnits);

  static Future<List<ReadParams>> readParams(RandomAccessSource src) {
    return _findExif(src);
  }

  static Future<List<ReadParams>> _findExif(RandomAccessSource src) async {
    final fileBox = ISOBox.fileBox(src);
    final moov = await fileBox.getDirectChildByTypes({'moov'});
    final uuidList = await moov?.getDirectChildrenByTypes({'uuid'}) ?? const [];

    final res = <ReadParams>[];
    for (final uuidBox in uuidList) {
      final data = await uuidBox.extractData();
      if (data.length < 17) {
        continue;
      }
      final first16Bytes = data.subView(0, 16);
      final uuidString = first16Bytes.toHex();
      if (uuidString != '85c0b687820f11e08111f4ce462b6a48') {
        continue;
      }
      final contentBytes = data.subView(16);
      final contentBox = ISOBox.fileBoxFromBytes(contentBytes);
      final exifBoxes = await contentBox
          .getDirectChildrenByTypes({'CMT1', 'CMT2', 'CMT3', 'CMT4'});
      for (final exifBox in exifBoxes) {
        final exifData = await exifBox.extractData();
        if (exifData.length <= 2) {
          continue;
        }
        final endian = BinaryReader.endianOfByte(exifData[0]);
        Map<int, MakerTag>? tagDict;
        bool cr3MakerNote = false;
        if (exifBox.type == 'CMT3') {
          tagDict = canon_.MakerNoteCanon.tags;
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
      break;
    }
    return res;
  }
}
