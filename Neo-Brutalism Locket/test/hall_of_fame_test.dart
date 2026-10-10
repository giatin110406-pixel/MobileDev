import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_screen.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/entry_export.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_screen.dart';
import 'package:neo_brutalism_locket/features/contest/hall_of_fame_screen.dart';
import 'package:neo_brutalism_locket/features/contest/hall_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import 'canvas_store_test.dart' show FakeCanvas;
import 'contest_test.dart';

GalleryEntry winner(int n, {int? rank, String? week}) => GalleryEntry(
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
  weekKey: week ?? '2026-W${40 - n}',
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
  group('the podium colours', () {
    test('the pedestals are yellow, blue and orange by rank', () {
      expect(hallFrameColor(1), const Color(0xFFFFE66D));
      expect(hallFrameColor(2), const Color(0xFF45B7D1));
      expect(hallFrameColor(3), const Color(0xFFF7A072));
      expect(hallFrameColor(null), hallFrameColor(3));
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
    testWidgets('an empty hall still shows the podium and explains itself', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(app(HallOfFameScreen(repository: FakeContest())));
      await tester.pump();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('?'), findsNWidgets(3));
      expect(
        find.textContaining('Nothing has been honoured yet'),
        findsOneWidget,
      );
      await leave(tester);
    });

    testWidgets('the newest week stands on the podium, first in the middle', (
      tester,
    ) async {
      bigScreen(tester);
      final repo = FakeContest();
      // Week 39 (newest) has all three places, week 38 has first place only.
      repo.hall.addAll([
        winner(1, rank: 1),
        winner(2, rank: 2, week: '2026-W39'),
        winner(3, rank: 3, week: '2026-W39'),
        winner(4, rank: 1),
      ]);
      await tester.pumpWidget(app(HallOfFameScreen(repository: repo)));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('W39'), findsOneWidget);
      expect(find.text('Team 1'), findsOneWidget);
      expect(find.text('Team 2'), findsOneWidget);
      expect(find.text('Team 3'), findsOneWidget);
      // Second place is left of first, third is right of it.
      final first = tester.getCenter(find.text('Team 1')).dx;
      expect(tester.getCenter(find.text('Team 2')).dx, lessThan(first));
      expect(tester.getCenter(find.text('Team 3')).dx, greaterThan(first));
      await leave(tester);
    });

    testWidgets('the arrows go to earlier weeks and back', (tester) async {
      bigScreen(tester);
      final repo = FakeContest();
      repo.hall.addAll([winner(1, rank: 1), winner(4, rank: 1)]);
      await tester.pumpWidget(app(HallOfFameScreen(repository: repo)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Team 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Earlier week'));
      await tester.pump();
      expect(find.text('Team 4'), findsOneWidget);
      expect(find.text('Team 1'), findsNothing);
      await tester.tap(find.byTooltip('Later week'));
      await tester.pump();
      expect(find.text('Team 1'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('tapping a winning painting opens it', (tester) async {
      bigScreen(tester);
      final repo = FakeContest();
      repo.hall.add(winner(1, rank: 1));
      repo.entries.add(winner(1, rank: 1));
      await tester.pumpWidget(app(HallOfFameScreen(repository: repo)));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(PixelArt));
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
      expect(find.text('Team 1'), findsOneWidget);
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
