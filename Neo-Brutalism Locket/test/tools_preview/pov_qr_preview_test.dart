// Renders the Omni POV code sheet to a PNG file, for a person (or a QR decoder) to look at:
//   flutter test test/tools_preview/pov_qr_preview_test.dart --dart-define=POV_QR_OUT=the.png
// Skipped when POV_QR_OUT is not given.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/pov/pov_qr_sheet.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import '../pov_store_test.dart' show FakePov, code32, me;

const out = String.fromEnvironment('POV_QR_OUT');

void main() {
  testWidgets('render the code sheet', (tester) async {
    if (out.isEmpty) return;
    tester.view.physicalSize = const Size(1200, 2700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakePov();
    final store = PovStore(repo, myId: me);
    await store.start();
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            backgroundColor: const Color(0xFFF8EED2),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PovQrSheet(store: store),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.code?.code, code32);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await tester.runAsync(() => boundary.toImage());
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    await tester.pumpWidget(const SizedBox());
    await store.end();
    store.dispose();
  });
}
