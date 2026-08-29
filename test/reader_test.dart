import 'dart:typed_data';

import 'package:exif_reader/src/field_types.dart';
import 'package:exif_reader/src/readers/reader.dart';
import 'package:random_access_source/random_access_source.dart';
import 'package:test/test.dart';

void main() {
  test('reads IFD entries in one block', () async {
    for (final endian in [Endian.little, Endian.big]) {
      final bytes = ByteData(34);
      bytes.setUint16(0, 2, endian);
      bytes
        ..setUint16(2, 0x010f, endian)
        ..setUint16(4, 2, endian)
        ..setUint32(6, 6, endian)
        ..setUint32(10, 28, endian)
        ..setUint16(14, 0x0112, endian)
        ..setUint16(16, 3, endian)
        ..setUint32(18, 1, endian)
        ..setUint16(22, 6, endian);
      final source = _CountingSource(bytes.buffer.asUint8List());
      final reader = IfdReader(
        BinaryReader(source, 0, endian),
        fakeExif: false,
      );

      final entries = await reader.readIfdEntries(0, relative: false);

      expect(entries, hasLength(2));
      expect(entries[0].tag, 0x010f);
      expect(entries[0].fieldType, FieldType.ascii);
      expect(entries[0].count, 6);
      expect(entries[0].fieldOffset, 28);
      expect(entries[1].tag, 0x0112);
      expect(entries[1].fieldType, FieldType.short);
      expect(entries[1].count, 1);
      expect(entries[1].fieldOffset, 22);

      final relativeEntries = await reader.readIfdEntries(0, relative: true);

      expect(relativeEntries[0].fieldOffset, 20);
      expect(relativeEntries[1].fieldOffset, 22);
      expect(source.readLengths, [2, 24, 2, 24]);
    }
  });

  test('batches numeric array reads', () async {
    final integers = ByteData(6)
      ..setInt16(0, -1, Endian.little)
      ..setInt16(2, 2, Endian.little)
      ..setInt16(4, -3, Endian.little);
    final integerSource = _CountingSource(integers.buffer.asUint8List());
    final integerReader = IfdReader(
      BinaryReader(integerSource, 0, Endian.little),
      fakeExif: false,
    );

    final integerValues = await integerReader.readField(
      IfdEntry(
        fieldOffset: 0,
        tag: 0,
        fieldType: FieldType.signedShort,
        count: 3,
      ),
      tagName: 'Values',
    );

    expect(integerValues.toList(), [-1, 2, -3]);
    expect(integerSource.readLengths, [6]);

    final ratios = ByteData(16)
      ..setInt32(0, 1)
      ..setInt32(4, 2)
      ..setInt32(8, -3)
      ..setInt32(12, 4);
    final ratioSource = _CountingSource(ratios.buffer.asUint8List());
    final ratioReader = IfdReader(
      BinaryReader(ratioSource, 0, Endian.big),
      fakeExif: false,
    );

    final ratioValues = await ratioReader.readField(
      IfdEntry(
        fieldOffset: 0,
        tag: 0,
        fieldType: FieldType.signedRatio,
        count: 2,
      ),
      tagName: 'Values',
    );

    expect(
      ratioValues.toList().map((value) => value.toString()),
      ['1/2', '-3/4'],
    );
    expect(ratioSource.readLengths, [16]);
  });

  test('chunks large numeric array reads', () async {
    final largeSource = _CountingSource(Uint8List(1001));
    final largeReader = IfdReader(
      BinaryReader(largeSource, 0, Endian.little),
      fakeExif: false,
    );

    final largeValues = await largeReader.readField(
      IfdEntry(
        fieldOffset: 0,
        tag: 0,
        fieldType: FieldType.undefined,
        count: 1001,
      ),
      tagName: 'MakerNote',
    );

    expect(largeValues.length, 1001);
    expect(largeSource.readLengths, [1000, 1]);
  });
}

class _CountingSource extends BytesRASource {
  _CountingSource(super.bytes);

  final readLengths = <int>[];

  @override
  Future<Uint8List> read(int count) {
    readLengths.add(count);
    return super.read(count);
  }
}
