// ignore: library_annotations
@TestOn('vm')
import 'dart:io' as io;

import 'package:exif_reader/exif_reader.dart';
import 'package:test/test.dart';

Future<void> _testFile(String name) async {
  final filename = 'test/data/$name';
  final file = io.File(filename);
  final output = tagsToString(await readExifFromFile(file));
  final expected = await io.File('$filename.dump').readAsString();
  expect(output, equals(expected.trim()));
}

void main() {
  test('read heic file', () async {
    await _testFile('heic-test.heic');
  });

  test('read png file', () async {
    await _testFile('png-test.png');
  });

  test('read avif file', () async {
    await _testFile('avif-test.avif');
  });

  test('read jxl file (uncompressed)', () async {
    await _testFile('jxl-test.jxl');
  });

  test('read jxl file (brob)', () async {
    await _testFile('jxl_meta_brob.jxl');
  });

  test('read webp file', () async {
    await _testFile('webp-test.webp');
  });

  test('read raf file', () async {
    await _testFile('t.RAF');
  });

  test('CR3', () async {
    await _testFile('t.CR3');
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
