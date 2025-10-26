import 'package:test/test.dart';

import '_test_file.dart';

void main() {
  test('read heic file', () => testFile('heic-test.heic'));

  test('read png file', () => testFile('png-test.png'));

  test('read avif file', () => testFile('avif-test.avif'));

  test(
    'read jxl file (uncompressed)',
    () => testFile('jxl-test.jxl'),
    testOn: 'vm',
  );

  test('read jxl file (brob)', () => testFile('jxl_meta_brob.jxl'),
      testOn: 'vm');

  test('read webp file', () => testFile('webp-test.webp'));

  test('read raf file', () => testFile('t.RAF'));

  test(
    'CR3',
    () => testFile('t.CR3'),
    testOn: 'vm',
  );
}
