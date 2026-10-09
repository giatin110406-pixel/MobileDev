import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';

/// In-memory canvas server for tests: a 4x4 canvas with 4 colours.
class FakeCanvas implements CanvasRepository {
  FakeCanvas({this.ink = 10, this.hasCanvas = true});

  int ink;
  final bool hasCanvas;
  final pixels = Uint8List(16);
  int version = 0;
  final events = <PixelEvent>[];
  final paints = <({String batch, List<PixelPatch> pixels})>[];
  final failures = <CanvasFailure>[];
  var eventCalls = 0;
  final _stream = StreamController<PixelEvent>.broadcast();

  CanvasData get snapshot => CanvasData(
    id: 'c1',
    groupId: 'g1',
    width: 4,
    height: 4,
    palette: const [0xFF000000, 0xFFFF0000, 0xFF00FF00, 0xFF0000FF],
    pixels: Uint8List.fromList(pixels),
    version: version,
    inkBalance: ink,
  );

  /// Another person paints a cell on the server.
  PixelEvent paintedByOther(int x, int y, int color, {bool broadcast = true}) {
    pixels[y * 4 + x] = color;
    final event = PixelEvent(
      x: x,
      y: y,
      color: color,
      version: ++version,
      userId: 'other',
    );
    events.add(event);
    if (broadcast) _stream.add(event);
    return event;
  }

  void broadcast(PixelEvent event) => _stream.add(event);

  @override
  Future<String?> activeCanvasId(String groupId) async =>
      hasCanvas ? 'c1' : null;

  @override
  Future<CanvasData> load(String canvasId) async => snapshot;

  @override
  Future<List<PixelEvent>> eventsSince(
    String canvasId,
    int version, {
    int limit = 500,
  }) async {
    eventCalls++;
    return events.where((e) => e.version > version).take(limit).toList();
  }

  @override
  Future<PaintResult> paint(
    String canvasId,
    String batchId,
    List<PixelPatch> patches,
  ) async {
    paints.add((batch: batchId, pixels: patches));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    var changed = 0;
    for (final patch in patches) {
      final index = patch.y * 4 + patch.x;
      if (pixels[index] == patch.color) continue;
      pixels[index] = patch.color;
      events.add(
        PixelEvent(
          x: patch.x,
          y: patch.y,
          color: patch.color,
          version: ++version,
          userId: 'me',
        ),
      );
      changed++;
    }
    ink -= changed;
    return PaintResult(version: version, inkBalance: ink, painted: changed);
  }

  @override
  Future<String> newCanvas(
    String groupId, {
    required int size,
    required String paletteId,
  }) async => 'c2';

  @override
  Future<int> rollback(String canvasId, String userId, DateTime since) async =>
      0;

  @override
  Stream<PixelEvent> watch(String canvasId) => _stream.stream;
}

Future<CanvasStore> ready(
  FakeCanvas repo, {
  Duration batchDelay = Duration.zero,
}) async {
  var n = 0;
  final store = CanvasStore(
    repo,
    groupId: 'g1',
    batchDelay: batchDelay,
    retryDelay: Duration.zero,
    newBatchId: () => 'batch-${n++}',
  );
  await store.load();
  return store;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('loading', () {
    test('shows the canvas, the palette and my Ink', () async {
      final repo = FakeCanvas(ink: 7);
      final store = await ready(repo);
      expect(store.status, CanvasStatus.ready);
      expect(store.width, 4);
      expect(store.palette.length, 4);
      expect(store.ink, 7);
      expect(store.canPaint, isTrue);
    });

    test('a group without a canvas is empty', () async {
      final store = await ready(FakeCanvas(hasCanvas: false));
      expect(store.status, CanvasStatus.empty);
      expect(store.canPaint, isFalse);
    });

    test('learns who painted what from the event log', () async {
      final repo = FakeCanvas()..paintedByOther(1, 1, 2, broadcast: false);
      final store = await ready(repo);
      await settle();
      expect(store.painterAt(1, 1), 'other');
      expect(store.painterAt(0, 0), isNull);
    });
  });

  group('painting', () {
    test('shows my pixel at once and counts its cost before sending', () async {
      final repo = FakeCanvas(ink: 5);
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      expect(store.paint(2, 1, 3), isTrue);
      expect(store.colorIndexAt(2, 1), 3);
      expect(store.isPending(2, 1), isTrue);
      expect(store.ink, 4);
      expect(repo.paints, isEmpty);
      await store.flushNow();
      expect(repo.paints.single.pixels.single.color, 3);
      expect(store.isPending(2, 1), isFalse);
      expect(store.ink, 4); // the server's balance now
    });

    test('painting the colour that is already there is free', () async {
      final repo = FakeCanvas(ink: 5);
      final store = await ready(repo);
      expect(store.paint(0, 0, 0), isTrue);
      await store.flushNow();
      expect(repo.paints, isEmpty);
      expect(store.ink, 5);
    });

    test('repainting a pending cell costs only once', () async {
      final repo = FakeCanvas(ink: 5);
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      store.paint(1, 1, 1);
      store.paint(1, 1, 2);
      expect(store.ink, 4);
      await store.flushNow();
      expect(repo.paints.single.pixels.single.color, 2);
    });

    test('with no Ink left it refuses and says why', () async {
      final repo = FakeCanvas(ink: 1);
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      expect(store.paint(0, 1, 1), isTrue);
      expect(store.paint(1, 1, 1), isFalse);
      expect(store.lastFailure, CanvasFailureKind.insufficientInk);
      expect(store.colorIndexAt(1, 1), 0);
    });

    test('rejects cells outside the canvas and colours outside the palette',
        () async {
      final store = await ready(FakeCanvas());
      expect(store.paint(4, 0, 1), isFalse);
      expect(store.paint(0, -1, 1), isFalse);
      expect(store.paint(0, 0, 9), isFalse);
    });

    test('sends at most 10 pixels per batch, each batch with its own id',
        () async {
      final repo = FakeCanvas(ink: 20);
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      for (var i = 0; i < 12; i++) {
        store.paint(i % 4, i ~/ 4, 1);
      }
      await store.flushNow();
      expect(repo.paints.map((p) => p.pixels.length), [10, 2]);
      expect(repo.paints.map((p) => p.batch).toSet().length, 2);
      expect(store.ink, 8);
    });

    test('when the server refuses, my pixels go back to what they were',
        () async {
      final repo = FakeCanvas(ink: 5)
        ..failures.add(const CanvasFailure(CanvasFailureKind.insufficientInk));
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      store.paint(3, 3, 2);
      await store.flushNow();
      await settle();
      expect(store.colorIndexAt(3, 3), 0);
      expect(store.isPending(3, 3), isFalse);
      expect(store.lastFailure, CanvasFailureKind.insufficientInk);
    });
  });

  group('connection trouble', () {
    test('a dropped connection retries the same batch and then succeeds',
        () async {
      final repo = FakeCanvas(ink: 5)
        ..failures.addAll([
          const CanvasFailure(CanvasFailureKind.network),
          const CanvasFailure(CanvasFailureKind.network),
        ]);
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      store.paint(0, 0, 1);
      await store.flushNow();
      expect(repo.paints.length, 3);
      expect(repo.paints.map((p) => p.batch).toSet().length, 1);
      expect(store.offline, isFalse);
      expect(repo.pixels[0], 1);
    });

    test('staying down makes the canvas view-only and undoes the pixel',
        () async {
      final repo = FakeCanvas(ink: 5)
        ..failures.addAll([
          for (var i = 0; i < 3; i++)
            const CanvasFailure(CanvasFailureKind.network),
        ]);
      final store = await ready(repo, batchDelay: const Duration(hours: 1));
      store.paint(0, 0, 1);
      await store.flushNow();
      expect(store.offline, isTrue);
      expect(store.canPaint, isFalse);
      expect(store.colorIndexAt(0, 0), 0);
      expect(store.paint(1, 0, 1), isFalse);
    });
  });

  group('other people painting', () {
    test('their pixels appear in order', () async {
      final repo = FakeCanvas();
      final store = await ready(repo);
      repo.paintedByOther(1, 0, 2);
      repo.paintedByOther(2, 0, 3);
      await settle();
      expect(store.colorIndexAt(1, 0), 2);
      expect(store.colorIndexAt(2, 0), 3);
      expect(store.version, 2);
      expect(store.painterAt(1, 0), 'other');
    });

    test('an event seen twice is applied once', () async {
      final repo = FakeCanvas();
      final store = await ready(repo);
      final event = repo.paintedByOther(0, 2, 1);
      repo.broadcast(event);
      await settle();
      expect(store.version, 1);
      expect(repo.eventCalls, 1); // only the author loading at start
    });

    test('a missed event is fetched instead of guessed', () async {
      final repo = FakeCanvas();
      final store = await ready(repo);
      await settle();
      final calls = repo.eventCalls;
      repo.paintedByOther(0, 0, 1, broadcast: false); // never arrives
      repo.paintedByOther(1, 0, 2); // arrives with a hole before it
      await settle();
      await settle();
      expect(repo.eventCalls, greaterThan(calls));
      expect(store.colorIndexAt(0, 0), 1);
      expect(store.colorIndexAt(1, 0), 2);
      expect(store.version, 2);
    });

    test('the last writer of a cell wins on screen', () async {
      final repo = FakeCanvas(ink: 5);
      final store = await ready(repo);
      store.paint(1, 1, 1);
      await store.flushNow();
      repo.paintedByOther(1, 1, 3);
      await settle();
      expect(store.colorIndexAt(1, 1), 3);
    });
  });
}
