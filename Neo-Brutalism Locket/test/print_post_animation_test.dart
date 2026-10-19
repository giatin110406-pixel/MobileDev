import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/print_sound.dart';
import 'package:neo_brutalism_locket/features/camera/print_post_animation.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final photo = NeoPhoto(
  id: 'photo-12',
  originalPath: '/no/such/file.jpg',
  createdAt: DateTime(2026, 1, 2, 9, 30),
  status: ProcessingStatus.done,
);

void main() {
  final buzzes = <String>[];
  final played = <String>[];

  setUp(() {
    buzzes.clear();
    played.clear();
    PrintSound.enabled = true;
    PrintSound.onPlay = played.add;
    Haptics.enabled = true;
    PrintEffect.enabled = true;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            buzzes.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    PrintEffect.enabled = true;
    PrintSound.enabled = true;
    PrintSound.onPlay = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(BuildContext) run, {
    Locale locale = const Locale('en'),
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => run(context),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );

  group('which stamp', () {
    test('a passed quest is always verified', () {
      expect(printStampFor(quest: true), PrintStamp.verified);
      expect(printStampFor(quest: true, private: true), PrintStamp.verified);
    });

    test('a post to everyone is approved', () {
      expect(printStampFor(quest: false), PrintStamp.approved);
    });

    test('a post to only some friends is top secret', () {
      expect(printStampFor(quest: false, private: true), PrintStamp.topSecret);
    });
  });

  testWidgets('prints, stamps, then closes by itself', (tester) async {
    var done = false;
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
      done = true;
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byType(PrintPostAnimation), findsOneWidget);
    expect(find.text('APPROVED'), findsNothing, reason: 'not stamped yet');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('APPROVED'), findsOneWidget);
    expect(done, isFalse);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(PrintPostAnimation), findsNothing);
    expect(done, isTrue);
  });

  testWidgets('a tap ends it early, once', (tester) async {
    var done = 0;
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
      done++;
    });
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(PrintPostAnimation), findsNothing);
    expect(done, 1);
  });

  testWidgets('it buzzes once per step and once for the stamp', (tester) async {
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    expect(
      buzzes.where((b) => b == 'HapticFeedbackType.selectionClick').length,
      PrintPostAnimation.steps,
    );
    expect(
      buzzes.where((b) => b == 'HapticFeedbackType.heavyImpact').length,
      1,
    );
  });

  testWidgets('the Vietnamese stamp', (tester) async {
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.verified);
    }, locale: const Locale('vi'));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('XÁC THỰC'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('switched off, it returns at once', (tester) async {
    PrintEffect.enabled = false;
    var done = false;
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
      done = true;
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byType(PrintPostAnimation), findsNothing);
    expect(done, isTrue);
  });

  testWidgets('reduce motion skips it', (tester) async {
    var done = false;
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
      done = true;
    }, reduceMotion: true);
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byType(PrintPostAnimation), findsNothing);
    expect(done, isTrue);
  });

  test('the setting is remembered and applied', () async {
    final settings = AppSettings();
    await settings.load();
    expect(settings.printEffectEnabled, isTrue);
    await settings.setPrintEffect(false);
    expect(PrintEffect.enabled, isFalse);

    final again = AppSettings();
    await again.load();
    expect(again.printEffectEnabled, isFalse);
    expect(PrintEffect.enabled, isFalse);
  });
  testWidgets('the printer sound starts, then the stamp thud', (tester) async {
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(played, [PrintSound.printerAsset]);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    expect(played, [PrintSound.printerAsset, PrintSound.stampAsset]);
  });

  testWidgets('sound off: the animation runs silent', (tester) async {
    PrintSound.enabled = false;
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    expect(played, isEmpty);
    expect(buzzes, isNotEmpty, reason: 'the haptics are a separate switch');
  });

  testWidgets('effect off or reduced motion: no sound either', (tester) async {
    PrintEffect.enabled = false;
    await pump(tester, (context) async {
      await playPrintPost(context, photo: photo, stamp: PrintStamp.approved);
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(played, isEmpty);
  });

  test('the sound setting is remembered and applied', () async {
    final settings = AppSettings();
    await settings.load();
    expect(settings.printSoundEnabled, isTrue);
    await settings.setPrintSound(false);
    expect(PrintSound.enabled, isFalse);
    final again = AppSettings();
    await again.load();
    expect(again.printSoundEnabled, isFalse);
  });

  test('the sound files exist', () {
    expect(
      File('assets/${PrintSound.printerAsset}').lengthSync(),
      greaterThan(1000),
    );
    expect(
      File('assets/${PrintSound.stampAsset}').lengthSync(),
      greaterThan(1000),
    );
  });
}
