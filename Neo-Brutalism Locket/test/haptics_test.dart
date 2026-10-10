import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final buzzes = <String>[];

  setUp(() {
    buzzes.clear();
    Haptics.enabled = true;
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            buzzes.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    Haptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a NeoButton buzzes when pressed, once', (tester) async {
    await tester.pumpWidget(host(NeoButton(label: 'GO', onPressed: () {})));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('GO')),
    );
    await tester.pump();
    expect(buzzes, ['HapticFeedbackType.mediumImpact']);
    await gesture.up();
    await tester.pump();
    expect(buzzes, hasLength(1));
  });

  testWidgets('a disabled NeoButton stays silent', (tester) async {
    await tester.pumpWidget(
      host(const NeoButton(label: 'GO', onPressed: null)),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('GO')),
    );
    await tester.pump();
    await gesture.up();
    expect(buzzes, isEmpty);
  });

  testWidgets('a NeoSwitch gives a detent click and still toggles', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      host(NeoSwitch(label: 'X', value: value, onChanged: (v) => value = v)),
    );
    await tester.tap(find.text('X'));
    await tester.pump();
    expect(value, isTrue);
    expect(buzzes, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('a NeoIconButton ticks lightly and still fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        NeoIconButton(icon: Icons.add, tooltip: 'add', onPressed: () => taps++),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(taps, 1);
    expect(buzzes, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('with haptics off nothing buzzes but taps still work', (
    tester,
  ) async {
    Haptics.enabled = false;
    var taps = 0;
    await tester.pumpWidget(
      host(
        NeoIconButton(icon: Icons.add, tooltip: 'add', onPressed: () => taps++),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(taps, 1);
    expect(buzzes, isEmpty);
  });

  group('AppSettings', () {
    test('haptics default to on', () async {
      final settings = AppSettings();
      await settings.load();
      expect(settings.hapticsEnabled, isTrue);
      expect(Haptics.enabled, isTrue);
    });

    test('turning haptics off is remembered and applied', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.setHaptics(false);
      expect(Haptics.enabled, isFalse);

      Haptics.enabled = true;
      final reopened = AppSettings();
      await reopened.load();
      expect(reopened.hapticsEnabled, isFalse);
      expect(Haptics.enabled, isFalse);
    });
  });
}
