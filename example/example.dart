// ignore_for_file: avoid_print

import 'dart:io';

import 'package:exif_reader/src/read_exif.dart';
import 'package:random_access_source/random_access_source.dart';

Future<void> main(List<String> arguments) async {
  for (final filename in arguments) {
    print('Reading $filename ..');

    final data =
        await readExifFromSourceAsync(await FileRASource.load(File(filename)));

    if (data.warnings.isNotEmpty) {
      print('Warnings:');
      for (final warning in data.warnings) {
        print('  $warning');
      }
    }

    if (data.tags.isEmpty) {
      print('No EXIF information found');
      return;
    }

    for (final entry in data.tags.entries) {
      print('${entry.key}: ${entry.value}');
    }
  }
}
