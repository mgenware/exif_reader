// ignore: library_annotations
@TestOn('vm')
import 'dart:io' as io;

import 'package:exif_reader/exif_reader.dart';
import 'package:test/test.dart';

void main() {
  test('read heic file', () async {
    const filename = 'test/data/heic-test.heic';
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File('$filename.dump').readAsString();
    expect(output, equals(expected.trim()));
  });

  test('read png file', () async {
    const filename = 'test/data/png-test.png';
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File('$filename.dump').readAsString();
    expect(output, equals(expected.trim()));
  });

  test('read avif file', () async {
    const filename = 'test/data/avif-test.avif';
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File('$filename.dump').readAsString();
    expect(output, equals(expected.trim()));
  });

  test('read jxl file (uncompressed)', () async {
    const filename = 'test/data/jxl-test.jxl';
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File('$filename.dump').readAsString();
    expect(output, equals(expected.trim()));
  });

  test('read jxl file (brob)', () async {
    const filename = 'test/data/jxl_meta_brob.jxl';
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File('$filename.dump').readAsString();
    expect(output, equals(expected.trim()));
  });

  test('read webp file', () async {
    const filename = 'test/data/webp-test.webp';
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File('$filename.dump').readAsString();
    expect(output, equals(expected.trim()));
  });
}

String tagsToString(Map<String, IfdTag> tags) {
  final tagKeys = tags.keys.toList();
  tagKeys.sort();
  final prints = <String>[];

  for (final key in tagKeys) {
    final tag = tags[key];
    prints.add('$key (${tag!.tagType}): $tag');
  }

  return prints.join('\n');
}
