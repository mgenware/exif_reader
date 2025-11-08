import 'dart:io' as io;

import 'package:exif_reader/src/read_exif.dart';
import 'package:random_access_source/random_access_source.dart';
import 'package:test/test.dart';

import '_test_file.dart';

Future<void> testFile(String name) async {
  final filename = 'test/data/$name';

  final data = io.File(filename);
  final exif = await readExifFromSource(await FileRASource.load(data));
  final output = tagsToString(exif.tags);

  final control = io.File('$filename.dump');
  // Uncomment this line to update control files.
  // await control.writeAsString(output);

  final expected = (await control.readAsString()).trim();

  expect(output, equals(expected));
}
