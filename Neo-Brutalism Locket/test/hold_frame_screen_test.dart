import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/hold_frame/hold_frame_backend.dart';
import 'package:neo_brutalism_locket/features/hold_frame/hold_frame_screen.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

class FakeHoldBackend implements HoldFrameBackend {
  final controller = StreamController<HoldFrameUpdate>.broadcast();
  final armed = <bool>[];
  int captures = 0;
  bool stopped = false;
  bool unlocked = false;

  @override
  Stream<HoldFrameUpdate> get updates => controller.stream;

  @override
  Future<RewindStart> start() async => const RewindStart(
    textureId: 1,
    previewWidth: 640,
    previewHeight: 480,
    sensorOrientation: 90,
    front: false,
    handlesCropAndRotation: true,
  );

  @override
  Future<Uint8List> lock() async => Uint8List.fromList(_png);

  @override
  Future<void> unlock() async => unlocked = true;

  @override
  Future<void> arm(bool on) async => armed.add(on);

  @override
  Future<Uint8List> capture() async {
    captures++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> stop() async => stopped = true;
}

// A 1x1 transparent PNG.
const _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

Future<(FakeHoldBackend, Completer<Uint8List?>)> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final backend = FakeHoldBackend();
  final popped = Completer<Uint8List?>();
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context)
              .push<Uint8List>(
                MaterialPageRoute(
                  builder: (_) => HoldFrameScreen(backend: backend),
                ),
              )
              .then(popped.complete),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  return (backend, popped);
}

void main() {
  testWidgets('does not shoot until armed, then shoots once when ready', (
    t,
  ) async {
    final (backend, popped) = await _open(t);
    final l = AppLocalizations.of(t.element(find.byType(HoldFrameScreen)));

    await t.tap(find.byKey(const ValueKey('hold-primary')));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(l.holdFrameHandoff), findsOneWidget);

    // A ready frame before the person pressed start is ignored.
    backend.controller.add(
      const HoldFrameUpdate(state: 'aligned', ready: true),
    );
    await t.pump(const Duration(milliseconds: 20));
    expect(backend.captures, 0);

    await t.tap(find.byKey(const ValueKey('hold-primary')));
    await t.pump(const Duration(milliseconds: 500));
    expect(backend.armed, [true]);

    backend.controller.add(
      const HoldFrameUpdate(state: 'adjust', dx: .2, ready: false),
    );
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text(l.holdFrameRight), findsOneWidget);
    expect(backend.captures, 0);

    backend.controller.add(
      const HoldFrameUpdate(state: 'aligned', ready: true),
    );
    backend.controller.add(
      const HoldFrameUpdate(state: 'aligned', ready: true),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(backend.captures, 1);
    await t.pump(const Duration(milliseconds: 500));
    expect(backend.stopped, isTrue);
    expect(popped.isCompleted, isTrue);
  });

  testWidgets('says it is unsure instead of guessing', (t) async {
    final (backend, _) = await _open(t);
    final l = AppLocalizations.of(t.element(find.byType(HoldFrameScreen)));
    await t.tap(find.byKey(const ValueKey('hold-primary')));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byKey(const ValueKey('hold-primary')));
    await t.pump(const Duration(milliseconds: 500));

    backend.controller.add(
      const HoldFrameUpdate(state: 'unsure', reason: 'few'),
    );
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text(l.holdFrameUnsure), findsOneWidget);
    expect(backend.captures, 0);
  });

  testWidgets('closing releases the camera and returns nothing', (t) async {
    final (backend, popped) = await _open(t);
    await t.tap(find.byIcon(Icons.close));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(backend.stopped, isTrue);
    expect(popped.isCompleted, isTrue);
  });
}
