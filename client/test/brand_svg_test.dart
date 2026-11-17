// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

void main() {
  test('Verify all brand SVGs can be parsed by flutter_svg without errors', () async {
    final dir = Directory('assets/brand');
    expect(dir.existsSync(), isTrue, reason: 'assets/brand must exist');

    final svgFiles = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.svg'));
    expect(svgFiles.isNotEmpty, isTrue);

    for (final file in svgFiles) {
      final svgString = file.readAsStringSync();
      expect(svgString, isNotEmpty, reason: '${file.path} is empty');
      try {
        final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
        pictureInfo.picture.dispose();
      } catch (e, stack) {
        fail('❌ FAILED parsing ${file.path}: $e\n$stack');
      }
    }
  });
}
