import 'dart:js_interop';

import 'package:exif_reader/exif_reader.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

import '_test_file.dart';

Future<Response> _download(String url) async {
  final res = await window.fetch(url.toJS).toDart;
  if (res.status != 200) {
    throw Exception('File not found: $url');
  }
  return res;
}

Future<void> testFile(String name) async {
  final filename = 'data/$name';

  final data = await _download(filename);
  final bytes = (await data.bytes().toDart).toDart;
  final exif = await readExifFromBytes(bytes);
  final output = tagsToString(exif.tags);

  final control = await _download('$filename.dump');
  final expected = (await control.text().toDart).toDart.trim();

  expect(output, equals(expected));
}
