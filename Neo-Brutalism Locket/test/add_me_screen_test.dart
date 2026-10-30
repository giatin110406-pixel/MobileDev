import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/add_me/add_me_backend.dart';
import 'package:neo_brutalism_locket/features/add_me/add_me_screen.dart';
import 'package:neo_brutalism_locket/features/hold_frame/hold_frame_backend.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

// A 1x1 PNG, so Image.memory has something real to decode.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeCamera implements HoldFrameBackend {
  final controller = StreamController<HoldFrameUpdate>.broadcast();
  final calls = <String>[];
  var shots = 0;

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
  Future<Uint8List> lock() async {
    calls.add('lock');
    return _png;
  }

  @override
  Future<void> unlock() async => calls.add('unlock');

  @override
  Future<void> arm(bool on) async => calls.add('arm $on');

  @override
  Future<Uint8List> capture() async {
    calls.add('capture');
    shots++;
    return Uint8List.fromList([..._png, shots]);
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

class FakeMerger implements AddMeBackend {
  FakeMerger(this.answers);
  final List<AddMeOutcome> answers;
  final pairs = <(Uint8List, Uint8List)>[];

  @override
  Future<AddMeOutcome> merge(Uint8List first, Uint8List second) async {
    pairs.add((first, second));
    return answers.removeAt(0);
  }
}

Future<Completer<Uint8List?>> open(
  WidgetTester t,
  FakeCamera camera,
  FakeMerger merger,
) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
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
                  builder: (_) => AddMeScreen(camera: camera, merger: merger),
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
  return popped;
}

Future<void> tapKey(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

String shown(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('add-me-text'))).data!;

void main() {
  late AppLocalizations l;

  testWidgets('group, then me, merged and used', (t) async {
    final camera = FakeCamera();
    final merged = Uint8List.fromList([..._png, 99]);
    final merger = FakeMerger([AddMeOutcome.merged(merged)]);
    final popped = await open(t, camera, merger);
    l = AppLocalizations.of(t.element(find.byType(AddMeScreen)));
    expect(shown(t), l.addMeStep1);

    await tapKey(t, 'add-me-first');
    // The frame is locked on photo 1 before it is taken.
    expect(camera.calls, ['lock', 'capture']);
    expect(shown(t), l.addMeStep2);

    // The helper is guided back onto photo 1's frame.
    camera.controller.add(const HoldFrameUpdate(state: 'adjust', dx: .2));
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text(l.holdFrameRight), findsOneWidget);
    // A little off is good enough for the merge, and the helper is told so.
    camera.controller.add(
      const HoldFrameUpdate(state: 'adjust', dx: .05, roll: 3),
    );
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text(l.addMeCloseEnough), findsOneWidget);
    camera.controller.add(const HoldFrameUpdate(state: 'aligned'));
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text(l.addMeAligned), findsOneWidget);

    await tapKey(t, 'add-me-second');
    expect(merger.pairs.single.$1.last, 1);
    expect(merger.pairs.single.$2.last, 2);
    expect(shown(t), l.addMeCheckResult);

    await tapKey(t, 'add-me-use');
    expect(popped.isCompleted, isTrue);
    expect(await popped.future, merged);
    expect(camera.calls.last, 'stop');
  });

  testWidgets('a refusal says why and photo 2 can be retaken', (t) async {
    final camera = FakeCamera();
    final merger = FakeMerger([
      const AddMeOutcome.refused('needs_matting'),
      AddMeOutcome.merged(_png),
    ]);
    await open(t, camera, merger);
    l = AppLocalizations.of(t.element(find.byType(AddMeScreen)));
    await tapKey(t, 'add-me-first');
    await tapKey(t, 'add-me-second');
    expect(shown(t), l.addMeNeedsMatting);

    await tapKey(t, 'add-me-retake');
    expect(shown(t), l.addMeStep2);
    await tapKey(t, 'add-me-second');
    // Photo 1 is kept: the retake is merged with the same group photo.
    expect(merger.pairs.map((p) => p.$1.last), [1, 1]);
    expect(merger.pairs.map((p) => p.$2.last), [2, 3]);
    expect(shown(t), l.addMeCheckResult);
  });

  testWidgets('every refusal reason has its own words', (t) async {
    for (final (reason, text) in [
      ('align_failed', (AppLocalizations l) => l.addMeAlignFailed),
      ('background_changed', (AppLocalizations l) => l.addMeBackgroundChanged),
      ('several_changes', (AppLocalizations l) => l.addMeBackgroundChanged),
      ('no_new_person', (AppLocalizations l) => l.addMeNoNewPerson),
      ('change_too_large', (AppLocalizations l) => l.addMeTooLarge),
    ]) {
      final camera = FakeCamera();
      await open(t, camera, FakeMerger([AddMeOutcome.refused(reason)]));
      l = AppLocalizations.of(t.element(find.byType(AddMeScreen)));
      await tapKey(t, 'add-me-first');
      await tapKey(t, 'add-me-second');
      expect(shown(t), text(l), reason: reason);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('closing gives nothing back and frees the camera', (t) async {
    final camera = FakeCamera();
    final popped = await open(t, camera, FakeMerger([]));
    await t.tap(find.byIcon(Icons.close));
    await t.pump(const Duration(milliseconds: 500));
    expect(popped.isCompleted, isTrue);
    expect(await popped.future, isNull);
    expect(camera.calls.last, 'stop');
  });

  testWidgets('who is in front can be switched when it was a choice', (t) async {
    final camera = FakeCamera();
    final behind = Uint8List.fromList([..._png, 10]);
    final front = Uint8List.fromList([..._png, 11]);
    final merger = FakeMerger([AddMeOutcome.merged(behind, alternative: front)]);
    final popped = await open(t, camera, merger);
    l = AppLocalizations.of(t.element(find.byType(AddMeScreen)));
    await tapKey(t, 'add-me-first');
    await tapKey(t, 'add-me-second');
    expect(find.text(l.addMeInFrontOfThem), findsOneWidget);
    await tapKey(t, 'add-me-layer');
    expect(find.text(l.addMeBehindThem), findsOneWidget);
    await tapKey(t, 'add-me-use');
    // The one on screen is the one that is used.
    expect(await popped.future, front);
  });

  testWidgets('no switch when there was nothing to choose', (t) async {
    final camera = FakeCamera();
    final merger = FakeMerger([AddMeOutcome.merged(_png)]);
    await open(t, camera, merger);
    await tapKey(t, 'add-me-first');
    await tapKey(t, 'add-me-second');
    expect(find.byKey(const ValueKey('add-me-layer')), findsNothing);
  });
}
