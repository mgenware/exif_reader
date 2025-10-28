// ignore_for_file: avoid_print

import 'dart:io';

import 'package:exif_reader/exif_reader_vm.dart';

Future<void> main(List<String> arguments) async {
  for (final filename in arguments) {
    print('Reading $filename ..');

    final data = await readExifFromFile(File(filename));

    if (data.isEmpty) {
      print('No EXIF information found');
      return;
    }

    for (final entry in data.entries) {
      print('${entry.key}: ${entry.value}');
    }
  }
}
