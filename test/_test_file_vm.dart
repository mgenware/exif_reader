import 'dart:io' as io;

import 'package:exif_reader/exif_reader_vm.dart';
import 'package:test/test.dart';

import '_test_file.dart';

Future<void> testFile(String name) async {
  final filename = 'test/data/$name';

  final data = io.File(filename);
  final output = tagsToString(await readExifFromFile(data));

  final control = io.File('$filename.dump');
  final expected = (await control.readAsString()).trim();

  expect(output, equals(expected));
}
