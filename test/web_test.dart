@TestOn('browser')
import 'dart:convert';

import 'package:exif_dart/exif.dart';
import 'package:test/test.dart';

import 'sample_file.dart';

void main() {
  test('run hybrid main', () async {
    final channel = spawnHybridUri('web_hybrid_main.dart');

    await for (final msg in channel.stream) {
      final file = SampleFile.fromJson(
          json.decode(msg as String) as Map<String, dynamic>);
      // ignore: avoid_print
      print(file.name);
      expect(await printExifOfBytes(file.getContent()), equals(file.dump),
          reason: 'file=${file.name}');
    }
  }, timeout: Timeout.parse('60s'));
}
