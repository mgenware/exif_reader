import 'package:exif_reader/exif_reader.dart';

import '_test_file_generic.dart'
    if (dart.library.io) '_test_file_vm.dart'
    if (dart.library.js_interop) '_test_file_web.dart' as impl_;

Future<void> testFile(String name) => impl_.testFile(name);

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
