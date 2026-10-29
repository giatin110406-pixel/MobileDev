import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/camera/shot_camera.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_picker.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Only turns a frame upright; the picker needs nothing else of the camera.
class _Backend implements RewindBackend {
  final finalized = <String>[];

  @override
  Future<Uint8List> finalizeFrame(String path, int rotation) async {
    finalized.add(path);
    return Uint8List.fromList([9, 9]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory dir;
  late String still;
  late List<RewindFrame> frames;
  late _Backend backend;
  final stillReads = <String>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rewind_picker_test');
    final png = img.encodePng(img.Image(width: 4, height: 4));
    still = (File('${dir.path}/hq.png')..writeAsBytesSync(png)).path;
    frames = [
      for (final offset in [400, -600, -100])
        RewindFrame(
          path: (File('${dir.path}/f$offset.png')..writeAsBytesSync(png)).path,
          offsetMs: offset,
          rotation: 90,
        ),
    ];
    backend = _Backend();
    stillReads.clear();
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps a picture open while it is still being read.
    }
  });

  /// Opens the picker and returns what it pops (once [act] has run).
  Future<RewindChoice?> run(
    WidgetTester tester, {
    String? current,
    required Future<void> Function() act,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    RewindChoice? popped;
    var done = false;
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
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<RewindChoice>(
                MaterialPageRoute(
                  builder: (_) => RewindPicker(
                    burst: ShotBurst(shotId: 's', frames: frames),
                    stillPath: still,
                    currentFramePath: current,
                    readStill: (path) async {
                      stillReads.add(path);
                      return Uint8List.fromList([1]);
                    },
                    backend: backend,
                  ),
                ),
              );
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return popped;
  }

  testWidgets('opens on the picture taken at the press; using it changes '
      'nothing', (tester) async {
    final choice = await run(
      tester,
      act: () async {
        expect(find.text('AS SHOT'), findsWidgets);
        await tester.tap(find.text('USE THIS FRAME'));
      },
    );
    expect(choice, isNull);
    expect(stillReads, isEmpty);
  });

  testWidgets('the frames are in time order and picking one returns it '
      'upright', (tester) async {
    final choice = await run(
      tester,
      act: () async {
        // Strip: AS SHOT, -0.6s, -0.1s, +0.4s (frames were given out of order).
        expect(find.text('-0.6s'), findsOneWidget);
        expect(find.text('-0.1s'), findsOneWidget);
        expect(find.text('+0.4s'), findsOneWidget);
        await tester.tap(find.text('-0.6s'));
        await tester.pump();
        await tester.tap(find.text('USE THIS FRAME'));
      },
    );
    expect(choice?.framePath, frames[1].path);
    expect(choice?.bytes, [9, 9]);
    expect(backend.finalized, [frames[1].path]);
  });

  testWidgets('going back to the picture from the press returns it', (
    tester,
  ) async {
    final choice = await run(
      tester,
      current: frames[2].path,
      act: () async {
        // Opens on the frame printed now; tap the original.
        await tester.tap(find.text('AS SHOT').last);
        await tester.pump();
        await tester.tap(find.text('USE THIS FRAME'));
      },
    );
    expect(choice?.framePath, isNull);
    expect(stillReads, [still]);
  });

  testWidgets('swiping the picture moves along the frames', (tester) async {
    final choice = await run(
      tester,
      act: () async {
        await tester.fling(
          find.byType(AspectRatio).first,
          const Offset(-300, 0),
          500,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('USE THIS FRAME'));
      },
    );
    // Swiping left goes to later frames.
    expect(choice, isNotNull);
    expect(choice!.framePath, isNotNull);
  });

  testWidgets('closing keeps the printed picture', (tester) async {
    final choice = await run(
      tester,
      act: () async {
        await tester.tap(find.byIcon(Icons.close));
      },
    );
    expect(choice, isNull);
  });
}
