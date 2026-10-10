import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_screen.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/entry_export.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_screen.dart';
import 'package:neo_brutalism_locket/features/contest/hall_of_fame_screen.dart';
import 'package:neo_brutalism_locket/features/contest/hall_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import 'canvas_store_test.dart' show FakeCanvas;
import 'contest_test.dart';

GalleryEntry winner(int n, {int? rank}) => GalleryEntry(
  id: 'w$n',
  contestId: 'c$n',
  seq: 1,
  groupName: 'Team $n',
  width: 2,
  height: 2,
  palette: const [0xFF000000, 0xFFFF0000],
  pixels: Uint8List.fromList([0, 1, 1, 0]),
  submittedAt: t0,
  rank: rank ?? (n % 3) + 1,
  score: 3.5,
  voteCount: 4,
  weekKey: '2026-W${40 - n}',
  titleVi: 'Hoa hướng dương',
  titleEn: 'Sunflowers',
);

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

class FakeExporter implements EntryExporter {
  final calls = <String>[];
  bool works = true;

  @override
  Future<bool> save(GalleryEntry entry) async {
    calls.add('save:${entry.id}');
    return works;
  }

  @override
  Future<bool> share(GalleryEntry entry, {String text = ''}) async {
    calls.add('share:${entry.id}:$text');
    return works;
  }
}

void main() {
  group('the Hall of Fame room', () {
    test(
      'every painting has a bay of its own, twice the size, alternating',
      () {
        final slots = layoutHall(11);
        expect(slots.length, 11);
        for (final slot in slots) {
          expect(slot.size, 2.0);
          expect(slot.side, slot.index.isEven ? -1 : 1);
          expect(slot.yTop, greaterThanOrEqualTo(Corridor.wallTop));
          expect(slot.yBottom, lessThanOrEqualTo(Corridor.wallBottom));
          expect(slot.z0, greaterThanOrEqualTo(Corridor.startZ));
        }
      },
    );

    test('nothing overlaps, and newer paintings are nearer the entrance', () {
      final slots = layoutHall(40);
      for (var i = 0; i < slots.length; i++) {
        for (var j = i + 1; j < slots.length; j++) {
          final a = slots[i], b = slots[j];
          if (a.side != b.side) continue;
          final overlap = a.z0 < b.z1 && b.z0 < a.z1;
          expect(overlap, isFalse, reason: 'bays $i and $j overlap');
        }
      }
      for (var i = 1; i < slots.length; i++) {
        expect(
          slots[i].z0,
          greaterThanOrEqualTo(slots[i - 2 < 0 ? 0 : i - 2].z0),
        );
      }
      expect(layoutHall(0), isEmpty);
    });

    test('a hall of 3 reaches further than the Gallery needs for 3', () {
      expect(corridorLength(layoutHall(3)), greaterThan(Corridor.startZ + 4));
    });

    test('the frames are gold, silver and bronze by rank', () {
      expect(hallFrameColor(1), const Color(0xFFD4A82E));
      expect(hallFrameColor(2), const Color(0xFFB9BEC7));
      expect(hallFrameColor(3), const Color(0xFFB0703A));
      expect(hallFrameColor(null), hallFrameColor(3));
    });

    test(
      'a painting gets a spot light and a plate with group, week, theme',
      () {
        final decor = hallDecor(winner(1, rank: 1), vietnamese: false);
        expect(decor.spot, isTrue);
        expect(decor.frame, hallFrameColor(1));
        expect(decor.plaque, ['Team 1', 'W39: Sunflowers']);
        expect(
          hallDecor(winner(1, rank: 1), vietnamese: true).plaque.last,
          'W39: Hoa hướng dương',
        );
      },
    );

    test('the hall looks different from the Gallery', () {
      expect(CorridorStyle.hall.wall, isNot(CorridorStyle.gallery.wall));
      expect(CorridorStyle.hall.ceilingLights, isFalse);
      expect(CorridorStyle.gallery.ceilingLights, isTrue);
    });
  });

  group('HallStore', () {
    test('loads a page at a time and stops at the last', () async {
      final repo = FakeContest();
      for (var i = 1; i <= 30; i++) {
        repo.hall.add(winner(i));
      }
      final store = HallStore(repo, pageSize: 12);
      await store.load();
      expect(store.entries.length, 12);
      expect(store.hasMore, isTrue);
      await store.loadMore();
      await store.loadMore();
      expect(store.entries.length, 30);
      expect(store.hasMore, isFalse);
      await store.loadMore(); // nothing more to ask
      expect(store.entries.length, 30);
    });

    test('an empty hall is loaded and empty', () async {
      final store = HallStore(FakeContest());
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.entries, isEmpty);
    });

    test('a failed page keeps what is there and can be retried', () async {
      final repo = FakeContest();
      for (var i = 1; i <= 20; i++) {
        repo.hall.add(winner(i));
      }
      final store = HallStore(repo, pageSize: 12);
      await store.load();
      repo.failNext = const ContestFailure(ContestFailureKind.network);
      await store.loadMore();
      expect(store.error?.kind, ContestFailureKind.network);
      expect(store.entries.length, 12);
      await store.loadMore();
      expect(store.error, isNull);
      expect(store.entries.length, 20);
    });
  });

  group('the Hall of Fame screen', () {
    final corridor = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CorridorPainter,
    );

    testWidgets('an empty hall explains itself', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(HallOfFameScreen(repository: FakeContest())));
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('Nothing has been honoured yet'),
        findsOneWidget,
      );
      await leave(tester);
    });

    testWidgets('shows the room, then a grid on request', (tester) async {
      bigScreen(tester);
      final repo = FakeContest();
      for (var i = 1; i <= 6; i++) {
        repo.hall.add(winner(i));
      }
      await tester.pumpWidget(app(HallOfFameScreen(repository: repo)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Hall of Fame'), findsOneWidget);
      expect(corridor, findsOneWidget);
      final painter =
          tester.widget<CustomPaint>(corridor).painter as CorridorPainter;
      expect(painter.style, same(CorridorStyle.hall));
      expect(painter.decorOf, isNotNull);
      await tester.tap(find.byTooltip('Switch to grid view'));
      await tester.pump();
      expect(corridor, findsNothing);
      expect(find.text('#1 · Team 1'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('tapping a painting in the room opens it', (tester) async {
      bigScreen(tester);
      final repo = FakeContest();
      for (var i = 1; i <= 6; i++) {
        repo.hall.add(winner(i));
        repo.entries.add(winner(i));
      }
      await tester.pumpWidget(app(HallOfFameScreen(repository: repo)));
      await tester.pump();
      await tester.pump();
      final topLeft = tester.getTopLeft(corridor);
      final size = tester.getSize(corridor);
      final first = layoutHall(6).first;
      final quad = Projection(size, 0).wallQuad(first)!;
      final centre = Offset(
        quad.map((p) => p.dx).reduce((a, b) => a + b) / 4,
        quad.map((p) => p.dy).reduce((a, b) => a + b) / 4,
      );
      await tester.tapAt(topLeft + centre);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetailScreen), findsOneWidget);
      expect(find.text('Team 1'), findsWidgets);
      await leave(tester);
    });

    testWidgets('a hall that cannot load offers a retry', (tester) async {
      bigScreen(tester);
      final repo = FakeContest()
        ..failNext = const ContestFailure(ContestFailureKind.network);
      repo.hall.add(winner(1));
      await tester.pumpWidget(app(HallOfFameScreen(repository: repo)));
      await tester.pump();
      await tester.pump();
      expect(find.text('TRY AGAIN'), findsOneWidget);
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pump();
      await tester.pump();
      expect(corridor, findsOneWidget);
      await leave(tester);
    });
  });

  group('ways in', () {
    testWidgets('the Gallery has a button to the Hall of Fame', (tester) async {
      bigScreen(tester);
      final repo = FakeContest()..entries.add(entryOf(1));
      await tester.pumpWidget(
        app(GalleryScreen(repository: repo, title: 'Starry')),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Hall of Fame'));
      await tester.pumpAndSettle();
      expect(find.byType(HallOfFameScreen), findsOneWidget);
      await leave(tester);
    });

    testWidgets(
      'the contest screen always offers the Gallery, even with no entry yet',
      (tester) async {
        bigScreen(tester);
        final repo = FakeContest(
          current: overviewOf(contest: contestInfo(accepted: 0)),
        );
        final store = ContestStore(repo, clock: () => t0);
        await tester.pumpWidget(
          app(ContestScreen(store: store, canvases: FakeCanvas())),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('ENTER GALLERY'), findsOneWidget);
        expect(find.text('HALL OF FAME'), findsOneWidget);
        await tester.tap(find.text('ENTER GALLERY'));
        await tester.pumpAndSettle();
        expect(find.byType(GalleryScreen), findsOneWidget);
        expect(find.textContaining('The corridor is empty'), findsOneWidget);
        await tester.tap(find.byTooltip('Back').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('HALL OF FAME'));
        await tester.pumpAndSettle();
        expect(find.byType(HallOfFameScreen), findsOneWidget);
        await leave(tester);
        store.dispose();
      },
    );
  });

  group('saving and sharing a painting', () {
    Future<(FakeContest, FakeExporter)> open(WidgetTester tester) async {
      bigScreen(tester);
      final entry = entryOf(2);
      final repo = FakeContest()..entries.add(entry);
      final exporter = FakeExporter();
      await tester.pumpWidget(
        app(
          EntryDetailScreen(repository: repo, entry: entry, exporter: exporter),
        ),
      );
      await tester.pump();
      await tester.pump();
      return (repo, exporter);
    }

    testWidgets('the buttons call the exporter and say how it went', (
      tester,
    ) async {
      final (_, exporter) = await open(tester);
      await tester.tap(find.text('SAVE PHOTO'));
      await tester.pump();
      await tester.pump();
      expect(exporter.calls, ['save:e2']);
      expect(find.text('Saved to your photo library.'), findsOneWidget);
      await tester.tap(find.text('SHARE'));
      await tester.pump();
      expect(exporter.calls.last, startsWith("share:e2:Group 2's painting"));
      await leave(tester);
    });

    testWidgets('a failure is told, not hidden', (tester) async {
      final (_, exporter) = await open(tester);
      exporter.works = false;
      await tester.tap(find.text('SAVE PHOTO'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Could not save'), findsOneWidget);
      await leave(tester);
    });

    test('the PNG is big, whole-pixel and a real PNG', () async {
      final entry = GalleryEntry(
        id: 'p',
        contestId: 'c',
        seq: 1,
        groupName: 'G',
        width: 32,
        height: 32,
        palette: const [0xFF000000, 0xFFFF0000],
        pixels: Uint8List(1024),
        submittedAt: t0,
      );
      final png = await renderEntryPng(entry);
      expect(png.sublist(0, 8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]); // PNG signature
      final header = ByteData.sublistView(png, 16, 24);
      expect(header.getUint32(0), 1024); // 32 cells x 32 pixels
      expect(header.getUint32(4), 1024);
      final small = await renderEntryPng(winner(1), minSize: 100);
      final smallHeader = ByteData.sublistView(small, 16, 24);
      expect(smallHeader.getUint32(0), 100); // 2 cells x 50 pixels
    });
  });
}
