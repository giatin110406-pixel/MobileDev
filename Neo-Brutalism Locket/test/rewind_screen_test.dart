import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

class FakeRewindBackend implements RewindBackend {
  final controller = StreamController<RewindEvent>.broadcast();
  int shutters = 0;
  int rearms = 0;
  bool stopped = false;
  bool failToStart = false;
  bool unlocked = true;
  final handoffs = <Uint8List>[];
  final finalized = <String>[];

  @override
  Stream<RewindEvent> get events => controller.stream;

  @override
  Future<RewindStart> start({required bool front}) async {
    if (failToStart) throw PlatformException(code: 'cameraBusy');
    return const RewindStart(
      textureId: 1,
      previewWidth: 1440,
      previewHeight: 1080,
      sensorOrientation: 90,
      front: false,
      handlesCropAndRotation: true,
    );
  }

  @override
  Future<void> shutter() async => shutters++;

  @override
  Future<void> rearm() async => rearms++;

  @override
  Future<Uint8List> finalizeFrame(String path, int rotation) async {
    finalized.add(path);
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Map<String, Object?>> stats() async => const {};

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<bool> dismissKeyguard() async => unlocked;

  @override
  Future<void> handoff(Uint8List bytes) async => handoffs.add(bytes);
}

/// Sends [event] as the native side would and lets the screen react.
Future<void> emit(
  WidgetTester tester,
  FakeRewindBackend backend,
  RewindEvent event,
) async {
  await tester.runAsync(() async {
    backend.controller.add(event);
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
}

void main() {
  late Directory dir;
  late List<RewindFrame> frames;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rewind_screen_test');
    final png = img.encodePng(img.Image(width: 4, height: 4));
    frames = [
      for (final offset in [-600, -100, 400])
        RewindFrame(
          path: (File('${dir.path}/f$offset.png')..writeAsBytesSync(png)).path,
          offsetMs: offset,
          rotation: 90,
        ),
    ];
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<Uint8List?> pumpScreen(
    WidgetTester tester,
    FakeRewindBackend backend, {
    bool lockscreen = false,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Uint8List? popped;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute(
                      builder: (_) => RewindScreen(
                        backend: backend,
                        lockscreen: lockscreen,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('shoot, pick the nearest frame and send it', (tester) async {
    final backend = FakeRewindBackend();
    await pumpScreen(tester, backend);
    expect(find.bySemanticsLabel('Capture'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Capture'));
    await tester.pump();
    expect(backend.shutters, 1);

    await emit(tester, backend, const RewindHolding());
    expect(find.text('HOLDING THE MOMENT...'), findsOneWidget);

    await emit(tester, backend, RewindFrozen(frames: frames, still: null));
    // No still: it opens on the frame nearest the press (-0.1s), and says it
    // is an extra frame.
    expect(find.text('EXTRA FRAME'), findsOneWidget);
    expect(find.text('-0.1s'), findsWidgets);

    await tester.tap(find.text('SEND'));
    await tester.pumpAndSettle();
    expect(backend.finalized, [frames[1].path]);
    // The screen closed and the camera was released.
    expect(find.text('SEND'), findsNothing);
    expect(backend.stopped, isTrue);
  });

  testWidgets('retake asks the camera to watch again', (tester) async {
    final backend = FakeRewindBackend();
    await pumpScreen(tester, backend);
    await tester.tap(find.bySemanticsLabel('Capture'));
    await tester.pump();
    await emit(tester, backend, RewindFrozen(frames: frames, still: null));

    await tester.tap(find.text('RETAKE'));
    await tester.pumpAndSettle();
    expect(backend.rearms, 1);
    expect(find.bySemanticsLabel('Capture'), findsOneWidget);
  });

  testWidgets('a busy camera says so and offers to try again', (tester) async {
    final backend = FakeRewindBackend()..failToStart = true;
    await pumpScreen(tester, backend);
    expect(find.text('THE CAMERA IS BUSY'), findsOneWidget);

    backend.failToStart = false;
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Capture'), findsOneWidget);
  });

  testWidgets('closing lets the camera go and returns nothing', (tester) async {
    final backend = FakeRewindBackend();
    await pumpScreen(tester, backend);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(backend.stopped, isTrue);
    expect(find.bySemanticsLabel('Capture'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('on the lock screen, sending waits for the unlock', (
    tester,
  ) async {
    final backend = FakeRewindBackend()..unlocked = false;
    await pumpScreen(tester, backend, lockscreen: true);
    await tester.tap(find.bySemanticsLabel('Capture'));
    await tester.pump();
    await emit(tester, backend, RewindFrozen(frames: frames, still: null));

    await tester.tap(find.text('SEND'));
    await tester.pumpAndSettle();
    // Not unlocked: nothing handed over, the choice is still on screen.
    expect(backend.handoffs, isEmpty);
    expect(find.text('UNLOCK THE PHONE TO SEND'), findsOneWidget);
    expect(find.text('EXTRA FRAME'), findsOneWidget);

    backend.unlocked = true;
    // Let the message go, then try again.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEND'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(backend.handoffs, [
      [1, 2, 3],
    ]);
  });

  testWidgets('nothing kept is reported plainly', (tester) async {
    final backend = FakeRewindBackend();
    await pumpScreen(tester, backend);
    await tester.tap(find.bySemanticsLabel('Capture'));
    await tester.pump();
    await emit(tester, backend, const RewindFrozen(frames: [], still: null));
    expect(find.text('NO FRAME WAS KEPT. TRY AGAIN.'), findsOneWidget);
  });
}
