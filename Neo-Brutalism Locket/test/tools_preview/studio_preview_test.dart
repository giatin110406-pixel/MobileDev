// Draws the strip studio screen to a PNG for a person to look at:
//   flutter test test/tools_preview/studio_preview_test.dart --dart-define=STUDIO_OUT=<file.png>
// Skipped when STUDIO_OUT is not given. Icons show as empty boxes (the icon font
// is not loaded in tests).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/strip/strip_render.dart';
import 'package:neo_brutalism_locket/features/strip/strip_studio_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

const out = String.fromEnvironment('STUDIO_OUT');

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(rootBundle.load(file));
  }
  await loader.load();
}

void main() {
  testWidgets('draw the studio', (tester) async {
    await loadFont('SpaceGrotesk', [
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]);
    await loadFont('PublicSans', [
      'assets/fonts/PublicSans-Regular.ttf',
      'assets/fonts/PublicSans-SemiBold.ttf',
      'assets/fonts/PublicSans-Bold.ttf',
      'assets/fonts/PublicSans-ExtraBold.ttf',
    ]);
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: NeoTheme.data,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: StripStudioScreen(
            photos: const [
              StripPhoto(path: 'van_gogh_sunflowers'),
              StripPhoto(path: 'van_gogh_irises'),
              StripPhoto(path: 'van_gogh_cafe_terrace_night'),
              StripPhoto(path: 'van_gogh_almond_blossom'),
              StripPhoto(path: 'van_gogh_harvest'),
              StripPhoto(path: 'van_gogh_wheatfield_cypresses'),
            ],
            title: 'Đà Lạt cùng hội',
            subtitle: '20 thg 10 – 23 thg 10, 2026',
            assets: () async => loadStripAssets(),
            loader: (path) async =>
                File('assets/styles/$path.jpg').readAsBytesSync(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(data!.buffer.asUint8List());
    });
  }, skip: out.isEmpty);
}
