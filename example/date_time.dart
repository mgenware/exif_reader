// ignore_for_file: avoid_print

import 'dart:io';

import 'package:exif_reader/exif_reader.dart';

Future<void> main(List<String> arguments) async {
  for (final filename in arguments) {
    print('read $filename ..');

    final fileBytes = await File(filename).readAsBytes();
    final exif = await readExifFromBytes(fileBytes);

    if (exif.warnings.isNotEmpty) {
      print('Warnings:');
      for (final warning in exif.warnings) {
        print('  $warning');
      }
    }

    if (exif.tags.isEmpty) {
      print('No EXIF information found');
      return;
    }

    final datetime = exif.tags['EXIF DateTimeOriginal']?.toString();
    if (datetime == null) {
      print('datetime information not found');
      return;
    }

    print('datetime = $datetime');
  }
}
