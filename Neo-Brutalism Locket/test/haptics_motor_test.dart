import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/features/settings/haptics_check.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The direct-to-motor buzz, the phone report and the vibration check.
void main() {
  const channel = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/haptics',
  );
  final system = <String>[];
  final motor = <Map<Object?, Object?>>[];
  late Object? Function(MethodCall) nativeAnswer;
  // What a phone without our native code (iOS, desktop) does: the channel has
  // no listener, which the app sees as a MissingPluginException.
  void noNativeSide() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    system.clear();
    motor.clear();
    Haptics.enabled = true;
    Haptics.direct = false;
    nativeAnswer = (call) {
      if (call.method == 'buzz') {
        motor.add(call.arguments as Map<Object?, Object?>);
        return true;
      }
      return null;
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        system.add(call.arguments as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => nativeAnswer(call),
    );
  });

  tearDown(() {
    Haptics.enabled = true;
    Haptics.direct = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('direct mode', () {
    test('drives the motor with a stronger buzz for a harder kind', () async {
      Haptics.direct = true;
      Haptics.press();
      Haptics.heavy();
      await Future<void>.delayed(Duration.zero);
      expect(system, isEmpty, reason: 'the system buzz is not used');
      expect(motor, hasLength(2));
      expect(
        motor[1]['amplitude'] as int,
        greaterThan(motor[0]['amplitude'] as int),
      );
      expect(motor[1]['ms'] as int, greaterThan(motor[0]['ms'] as int));
    });

    test('every kind has a real duration and strength', () {
      for (final kind in HapticKind.values) {
        final (ms, amplitude) = Haptics.motorPattern(kind);
        expect(ms, inInclusiveRange(1, 100), reason: kind.name);
        expect(amplitude, inInclusiveRange(1, 255), reason: kind.name);
      }
    });

    test('falls back to the system buzz when the phone has no motor', () async {
      Haptics.direct = true;
      nativeAnswer = (call) => false;
      Haptics.light();
      await Future<void>.delayed(Duration.zero);
      expect(system, ['HapticFeedbackType.lightImpact']);
    });

    test('falls back too when there is no native side at all', () async {
      Haptics.direct = true;
      noNativeSide();
      await Haptics.test(HapticKind.select, viaMotor: true);
      expect(system, ['HapticFeedbackType.selectionClick']);
    });

    test('switched off, nothing buzzes either way', () async {
      Haptics.enabled = false;
      Haptics.direct = true;
      Haptics.press();
      await Future<void>.delayed(Duration.zero);
      expect(system, isEmpty);
      expect(motor, isEmpty);
    });

    test('the check buzzes even when buzzing is switched off', () async {
      Haptics.enabled = false;
      expect(await Haptics.test(HapticKind.press, viaMotor: true), isTrue);
      expect(motor, hasLength(1));
      expect(await Haptics.test(HapticKind.press, viaMotor: false), isTrue);
      expect(system, ['HapticFeedbackType.mediumImpact']);
    });
  });

  group('tap helpers', () {
    test(
      'a missing handler stays missing, so a disabled control stays disabled',
      () {
        expect(Haptics.tap(null), isNull);
        expect(Haptics.tapWith<bool>(null), isNull);
      },
    );

    test('a tap buzzes, then runs the handler', () async {
      var ran = 0;
      Haptics.tap(() => ran++)!();
      await Future<void>.delayed(Duration.zero);
      expect(ran, 1);
      expect(system, ['HapticFeedbackType.lightImpact']);
    });

    test('a value handler gets its value', () async {
      bool? got;
      Haptics.tapWith<bool>((v) => got = v)!(true);
      await Future<void>.delayed(Duration.zero);
      expect(got, isTrue);
      expect(system, hasLength(1));
    });
  });

  group('what the phone reports', () {
    test('is read from the native side', () async {
      nativeAnswer = (call) => {
        'hasVibrator': true,
        'hasAmplitudeControl': true,
        'touchFeedbackOn': false,
        'sdk': 34,
      };
      final status = await Haptics.status();
      expect(status!.hasVibrator, isTrue);
      expect(status.hasAmplitudeControl, isTrue);
      expect(status.touchFeedbackOn, isFalse);
      expect(status.sdk, 34);
    });

    test('is unknown when there is no native side', () async {
      noNativeSide();
      expect(await Haptics.status(), isNull);
    });
  });

  group('settings', () {
    test('the direct choice is remembered and applied', () async {
      final settings = AppSettings();
      await settings.load();
      expect(settings.hapticsDirect, isFalse);
      await settings.setHapticsDirect(true);
      expect(Haptics.direct, isTrue);

      Haptics.direct = false;
      final reopened = AppSettings();
      await reopened.load();
      expect(reopened.hapticsDirect, isTrue);
      expect(Haptics.direct, isTrue);
    });
  });

  group('vibration check', () {
    Widget host() => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showHapticsCheck(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    Future<void> open(WidgetTester tester) async {
      // The buttons buzz when pressed; keep that out of the way, the check
      // buzzes whatever this switch says.
      Haptics.enabled = false;
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('tells a tester the phone has touch vibration off', (
      tester,
    ) async {
      nativeAnswer = (call) => {
        'hasVibrator': true,
        'hasAmplitudeControl': true,
        'touchFeedbackOn': false,
        'sdk': 34,
      };
      await open(tester);
      expect(find.text('VIBRATION CHECK'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
      expect(find.textContaining('touch vibration is OFF'), findsOneWidget);
    });

    testWidgets('says so when there is no motor', (tester) async {
      nativeAnswer = (call) => {
        'hasVibrator': false,
        'hasAmplitudeControl': false,
        'touchFeedbackOn': true,
        'sdk': 30,
      };
      await open(tester);
      expect(find.textContaining('no vibration motor'), findsOneWidget);
    });

    testWidgets('says when the device cannot report anything', (tester) async {
      noNativeSide();
      await open(tester);
      expect(find.textContaining('only Android reports it'), findsOneWidget);
    });

    testWidgets('each button runs three buzzes the way it says', (
      tester,
    ) async {
      nativeAnswer = (call) {
        if (call.method == 'buzz') {
          motor.add(call.arguments as Map<Object?, Object?>);
          return true;
        }
        return {
          'hasVibrator': true,
          'hasAmplitudeControl': true,
          'touchFeedbackOn': true,
          'sdk': 34,
        };
      };
      await open(tester);

      await tester.tap(find.text('TRY SYSTEM BUZZ'));
      await tester.pump(const Duration(seconds: 2));
      expect(system, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);

      system.clear();
      await tester.tap(find.text('TRY DIRECT BUZZ'));
      await tester.pump(const Duration(seconds: 2));
      expect(motor, hasLength(3));
      expect(system, isEmpty);
      await tester.pumpAndSettle();
    });
  });
}
