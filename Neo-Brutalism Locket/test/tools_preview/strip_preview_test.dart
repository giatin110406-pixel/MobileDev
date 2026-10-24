// Renders every strip style to PNG files for a person to look at:
//   flutter test test/tools_preview/strip_preview_test.dart --dart-define=STRIP_OUT=<folder>
// Skipped when STRIP_OUT is not given.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/strip/strip_render.dart';

const out = String.fromEnvironment('STRIP_OUT');

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(rootBundle.load(file));
  }
  await loader.load();
}

void main() {
  test('render every style', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFont('SpaceGrotesk', [
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]);
    final photos = [
      for (final name in [
        'sunflowers',
        'irises',
        'cafe_terrace_night',
        'almond_blossom',
        'wheatfield_cypresses',
        'harvest',
      ])
        await decodeStripPhoto(
          File('assets/styles/van_gogh_$name.jpg').readAsBytesSync(),
        ),
    ];
    final assets = await loadStripAssets();
    for (final style in StripStyle.values) {
      for (final (tag, paper, n) in [
        ('strip3', StripPaper.strip2x6, 3),
        ('strip2', StripPaper.strip2x6, 2),
        ('grid6', StripPaper.grid4x6, 6),
        ('grid4', StripPaper.grid4x6, 4),
      ]) {
        final image = await renderStrip(
          StripSpec(
            style: style,
            paper: paper,
            title: 'Đà Lạt cùng hội',
            subtitle: '20/10 – 23/10/2026',
          ),
          photos.take(n).toList(),
          assets: assets,
        );
        File(
          '$out/${style.name}_$tag.png',
        ).writeAsBytesSync(await stripPng(image));
      }
    }
  }, skip: out.isEmpty);
}
