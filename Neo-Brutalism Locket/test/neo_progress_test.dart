import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_progress.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_working_label.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: Center(child: SizedBox(width: 300, child: child)),
    ),
  ),
);

void main() {
  testWidgets('with a value it shows the label and the percent', (
    tester,
  ) async {
    await tester.pumpWidget(host(const NeoProgress(value: 0.42, label: 'GO')));
    expect(find.text('GO'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    // A bar that is full or empty must not throw.
    await tester.pumpWidget(host(const NeoProgress(value: 0)));
    await tester.pumpWidget(host(const NeoProgress(value: 1.7)));
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a value there is no percent and the block sweeps', (
    tester,
  ) async {
    await tester.pumpWidget(host(const NeoProgress(label: 'GO')));
    expect(find.textContaining('%'), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('when the phone asks for less motion nothing animates', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const NeoProgress(label: 'GO'), disableAnimations: true),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('percent can be hidden', (tester) async {
    await tester.pumpWidget(
      host(const NeoProgress(value: 0.5, showPercent: false)),
    );
    expect(find.text('50%'), findsNothing);
  });

  testWidgets('a determinate bar does not keep the frame loop busy', (
    tester,
  ) async {
    await tester.pumpWidget(host(const NeoProgress(value: 0.3)));
    await tester.pumpAndSettle();
  });

  test('the waiting label follows the style, in both languages', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(styleWorkingLabel(vi, StyleType.pixel8bit), 'ĐANG MÀI PIXEL…');
    expect(styleWorkingLabel(vi, StyleType.vanGogh), 'ĐANG QUÉT MÀU VAN GOGH…');
    expect(styleWorkingLabel(en, StyleType.pixel8bit), 'GRINDING PIXELS…');
    expect(styleWorkingLabel(vi, null), 'ĐANG XỬ LÝ…');
    expect(styleWorkingLabel(vi, StyleType.none), 'ĐANG XỬ LÝ…');
  });
}
