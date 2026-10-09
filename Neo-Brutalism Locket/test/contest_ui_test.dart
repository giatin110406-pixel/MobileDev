
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_screen.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_view.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_screen.dart';
import 'package:neo_brutalism_locket/features/contest/results_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import 'canvas_store_test.dart' show FakeCanvas;
import 'contest_test.dart';

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

void main() {
  group('banner', () {
    testWidgets('shows the theme, the phase and the entry counter', (
      tester,
    ) async {
      final store = ContestStore(
        FakeContest(current: overviewOf(contest: contestInfo(accepted: 87))),
        clock: () => t0,
      );
      await store.refresh();
      var tapped = false;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: ContestBanner(store: store, onTap: () => tapped = true),
          ),
        ),
      );
      expect(find.text('The Starry Night'), findsOneWidget);
      expect(find.textContaining('ĐANG NHẬN BÀI'), findsOneWidget);
      expect(find.text('87/100'), findsOneWidget);
      expect(find.textContaining('Còn 20:00:00'), findsOneWidget);
      await tester.tap(find.text('The Starry Night'));
      expect(tapped, isTrue);
      await leave(tester);
      store.dispose();
    });

    testWidgets('shows nothing until there is a contest', (tester) async {
      final store = ContestStore(FakeContest(), clock: () => t0);
      await store.refresh();
      await tester.pumpWidget(
        app(Scaffold(body: ContestBanner(store: store, onTap: () {}))),
      );
      expect(find.byType(Text), findsNothing);
      await leave(tester);
      store.dispose();
    });
  });

  group('contest screen', () {
    Future<(FakeContest, ContestStore)> open(
      WidgetTester tester,
      ContestOverview overview,
    ) async {
      bigScreen(tester);
      final repo = FakeContest(current: overview);
      final store = ContestStore(repo, clock: () => t0);
      await tester.pumpWidget(
        app(ContestScreen(store: store, canvases: FakeCanvas())),
      );
      await tester.pump();
      await tester.pump();
      return (repo, store);
    }

    testWidgets('an owner enters a group: preview, confirm, place', (
      tester,
    ) async {
      final (repo, store) = await open(
        tester,
        overviewOf(
          owned: const [OwnedGroup(id: 'g1', name: 'Painters', submitted: false)],
        ),
      );
      expect(find.text('The Starry Night'), findsOneWidget);
      expect(find.text('Painters'), findsOneWidget);
      await tester.tap(find.text('NỘP BÀI'));
      await tester.pumpAndSettle();
      expect(find.text('NỘP BÀI: Painters'), findsOneWidget);
      expect(find.textContaining('Đã có 5/100 bài'), findsOneWidget);
      await tester.tap(find.text('NỘP BÀI').last);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('submit:g1:c1'));
      expect(find.text('Đã nộp! Bài của bạn là số 7.'), findsOneWidget);
      await leave(tester);
      store.dispose();
    });

    testWidgets('a full contest says so inside the sheet', (tester) async {
      final (repo, store) = await open(
        tester,
        overviewOf(
          owned: const [OwnedGroup(id: 'g1', name: 'Painters', submitted: false)],
        ),
      );
      repo.failNext = const ContestFailure(ContestFailureKind.contestFull);
      await tester.tap(find.text('NỘP BÀI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NỘP BÀI').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('đã đủ 100 bài'), findsOneWidget);
      await leave(tester);
      store.dispose();
    });

    testWidgets('someone who does not own a group is told who can enter', (
      tester,
    ) async {
      final (_, store) = await open(tester, overviewOf());
      expect(find.textContaining('Chỉ trưởng nhóm mới nộp bài'), findsOneWidget);
      expect(find.text('NỘP BÀI'), findsNothing);
      await leave(tester);
      store.dispose();
    });

    testWidgets('while rating, a participant sees their progress', (
      tester,
    ) async {
      final (_, store) = await open(
        tester,
        overviewOf(
          contest: contestInfo(closesIn: const Duration(hours: -1)),
          participant: true,
          mine: const MyEntry(id: 'e1', seq: 4, groupName: 'Painters'),
          myVotes: 3,
          votesNeeded: 10,
        ),
      );
      expect(find.text('Bạn đã chấm 3/10 bài'), findsOneWidget);
      expect(find.textContaining('bài số 4'), findsOneWidget);
      expect(find.text('VÀO GALLERY (5 BÀI)'), findsOneWidget);
      await leave(tester);
      store.dispose();
    });

    testWidgets('a finished contest links to its results', (tester) async {
      final (_, store) = await open(
        tester,
        overviewOf(
          contest: contestInfo(phase: ContestPhase.finalized),
          previous: const PreviousContest(
            id: 'c0',
            weekKey: '2026-W40',
            titleVi: 'x',
            titleEn: 'Sunflowers',
          ),
        ),
      );
      expect(find.text('XEM KẾT QUẢ'), findsOneWidget);
      expect(find.textContaining('SUNFLOWERS'), findsOneWidget);
      await leave(tester);
      store.dispose();
    });

    testWidgets('a server that cannot be reached offers a retry', (
      tester,
    ) async {
      bigScreen(tester);
      final repo = FakeContest()
        ..failOverview = const ContestFailure(ContestFailureKind.network);
      final store = ContestStore(repo, clock: () => t0);
      await tester.pumpWidget(
        app(ContestScreen(store: store, canvases: FakeCanvas())),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Không tải được cuộc thi.'), findsOneWidget);
      repo
        ..failOverview = null
        ..current = overviewOf();
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pump();
      await tester.pump();
      expect(find.text('The Starry Night'), findsOneWidget);
      await leave(tester);
      store.dispose();
    });
  });

  group('gallery screen', () {
    Future<FakeContest> open(WidgetTester tester, int n) async {
      bigScreen(tester);
      final repo = FakeContest();
      for (var i = 1; i <= n; i++) {
        repo.entries.add(entryOf(i));
      }
      await tester.pumpWidget(
        app(GalleryScreen(repository: repo, title: 'The Starry Night')),
      );
      await tester.pump();
      await tester.pump();
      return repo;
    }

    final corridor = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CorridorPainter,
    );

    testWidgets('an empty gallery explains itself', (tester) async {
      await open(tester, 0);
      expect(find.textContaining('Hành lang còn trống'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('shows the corridor first, and a grid on request', (
      tester,
    ) async {
      await open(tester, 6);
      expect(corridor, findsOneWidget);
      expect(find.text('GALLERY ROOM'), findsOneWidget);
      expect(find.text('1 / 6'), findsOneWidget);
      await tester.tap(find.byTooltip('Xem dạng lưới'));
      await tester.pump();
      expect(corridor, findsNothing);
      expect(find.text('#1 · Group 1'), findsOneWidget);
      expect(find.text('#6 · Group 6'), findsOneWidget);
      await tester.tap(find.byTooltip('Xem dạng hành lang'));
      await tester.pump();
      expect(corridor, findsOneWidget);
      await leave(tester);
    });

    testWidgets('tapping a framed picture in the corridor opens it', (
      tester,
    ) async {
      await open(tester, 6);
      final topLeft = tester.getTopLeft(corridor);
      final size = tester.getSize(corridor);
      final slots = layoutFrames([for (var i = 1; i <= 6; i++) 'e$i']);
      final first = slots.firstWhere((s) => s.index == 0);
      final quad = Projection(size, 0).wallQuad(first)!;
      final centre = Offset(
        quad.map((p) => p.dx).reduce((a, b) => a + b) / 4,
        quad.map((p) => p.dy).reduce((a, b) => a + b) / 4,
      );
      await tester.tapAt(topLeft + centre);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetailScreen), findsOneWidget);
      expect(find.text('Group 1'), findsWidgets);
      await tester.tap(find.byTooltip('Quay lại').last);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetailScreen), findsNothing);
      await leave(tester);
    });

    testWidgets('walking forward moves the position', (tester) async {
      await open(tester, 40);
      expect(find.text('1 / 20+'), findsOneWidget); // 20 loaded, more to come
      await tester.tap(find.byTooltip('Đi tới'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đi tới'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 20+'), findsNothing);
      await leave(tester);
    });

    testWidgets('swiping up walks forward', (tester) async {
      await open(tester, 40);
      await tester.fling(corridor, const Offset(0, -300), 800);
      await tester.pumpAndSettle();
      expect(find.text('1 / 20+'), findsNothing);
      await leave(tester);
    });

    testWidgets('more pages load as the visitor nears the end', (tester) async {
      final repo = await open(tester, 45);
      expect(repo.pageLoads, 1);
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip('Đi tới'));
        await tester.pumpAndSettle();
      }
      expect(repo.pageLoads, greaterThan(1));
      await leave(tester);
    });
  });

  group('corridor view', () {
    testWidgets('keeps working when the entry list grows', (tester) async {
      bigScreen(tester);
      final cache = EntryImageCache();
      final opened = <String>[];
      Widget view(int n) => app(
        Scaffold(
          body: CorridorView(
            entries: [for (var i = 1; i <= n; i++) entryOf(i)],
            cache: cache,
            onOpen: (e) => opened.add(e.id),
          ),
        ),
      );
      await tester.pumpWidget(view(4));
      await tester.pumpWidget(view(8));
      expect(find.text('1 / 8'), findsOneWidget);
      await leave(tester);
      cache.dispose();
    });
  });

  group('entry detail', () {
    Future<FakeContest> open(
      WidgetTester tester, {
      bool participant = true,
      ContestPhase phase = ContestPhase.judging,
      GalleryEntry? entry,
    }) async {
      bigScreen(tester);
      final e = entry ?? entryOf(2);
      final repo = FakeContest()
        ..entries.add(e)
        ..detail = EntryDetail(
          entry: e,
          phase: phase,
          participant: participant,
          reactions: const {'🔥': 3},
          commentCount: 0,
        );
      await tester.pumpWidget(
        app(EntryDetailScreen(repository: repo, entry: e)),
      );
      await tester.pump();
      await tester.pump();
      return repo;
    }

    testWidgets('a participant rates with the stars', (tester) async {
      final repo = await open(tester);
      expect(find.textContaining('Chạm vào ngôi sao'), findsOneWidget);
      await tester.tap(find.byTooltip('Chấm 4 sao'));
      await tester.pump();
      expect(repo.calls, contains('vote:e2:4'));
      expect(find.textContaining('Bạn chấm 4 sao'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a refused rating goes back and says why', (tester) async {
      final repo = await open(tester);
      repo.failNext = const ContestFailure(ContestFailureKind.notJudging);
      await tester.tap(find.byTooltip('Chấm 5 sao'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Chạm vào ngôi sao'), findsOneWidget);
      expect(find.text('Hiện chưa phải lúc chấm điểm.'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('an outsider can look but not rate or comment', (tester) async {
      await open(tester, participant: false);
      expect(find.textContaining('Chỉ thành viên các nhóm'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await leave(tester);
    });

    testWidgets('you cannot rate your own group', (tester) async {
      await open(tester, entry: entryOf(2, mine: true));
      expect(find.textContaining('bài của nhóm bạn'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('writing a comment', (tester) async {
      final repo = await open(tester);
      await tester.enterText(find.byType(TextField), 'Beautiful colours');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, contains('comment:e2:Beautiful colours'));
      expect(find.text('Beautiful colours'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a comment that is too fast keeps the text and says why', (
      tester,
    ) async {
      final repo = await open(tester);
      repo.failNext = const ContestFailure(ContestFailureKind.tooFast);
      await tester.enterText(find.byType(TextField), 'again');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Chậm lại một chút'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'again',
      );
      await leave(tester);
    });

    testWidgets('after the contest the rank and score are shown', (
      tester,
    ) async {
      await open(
        tester,
        phase: ContestPhase.finalized,
        entry: entryOf(2, rank: 1, score: 3.7222),
      );
      expect(find.textContaining('HẠNG NHẤT'), findsOneWidget);
      expect(find.textContaining('3.72'), findsOneWidget);
      expect(find.textContaining('Cuộc thi đã kết thúc'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('reactions show their counts', (tester) async {
      await open(tester);
      expect(find.text('🔥 3'), findsOneWidget);
      await leave(tester);
    });
  });

  group('results screen', () {
    testWidgets('shows the podium', (tester) async {
      bigScreen(tester);
      final repo = FakeContest();
      await tester.pumpWidget(
        app(ResultsScreen(repository: repo, contestId: 'c1')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('HẠNG NHẤT'), findsOneWidget);
      expect(find.text('HẠNG NHÌ'), findsOneWidget);
      expect(find.text('HẠNG BA'), findsNothing); // only two had enough ratings
      expect(find.text('Group 2'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('with no ranked entries it says why', (tester) async {
      bigScreen(tester);
      final repo = FakeContest()
        ..resultsOf = const ContestResults(
          contestId: 'c1',
          weekKey: '2026-W40',
          phase: ContestPhase.finalized,
          titleVi: 'x',
          titleEn: 'Sunflowers',
          entryCount: 2,
          winners: [],
        );
      await tester.pumpWidget(
        app(ResultsScreen(repository: repo, contestId: 'c1')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('ít nhất 3 phiếu'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('before the end there are no results yet', (tester) async {
      bigScreen(tester);
      final repo = FakeContest()
        ..resultsOf = const ContestResults(
          contestId: 'c1',
          weekKey: '2026-W41',
          phase: ContestPhase.judging,
          titleVi: 'x',
          titleEn: 'Starry',
          entryCount: 40,
          winners: [],
        );
      await tester.pumpWidget(
        app(ResultsScreen(repository: repo, contestId: 'c1')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('23:59 Chủ nhật'), findsOneWidget);
      await leave(tester);
    });
  });
}
