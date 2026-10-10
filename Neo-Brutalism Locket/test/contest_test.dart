import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/entry_store.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_store.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';

final t0 = DateTime.utc(2026, 10, 10, 12); // a Saturday, noon UTC

GalleryEntry entryOf(
  int seq, {
  int? rank,
  double? score,
  int? myScore,
  bool mine = false,
}) => GalleryEntry(
  id: 'e$seq',
  contestId: 'c1',
  seq: seq,
  groupName: 'Group $seq',
  width: 2,
  height: 2,
  palette: const [0xFF000000, 0xFFFF0000],
  pixels: Uint8List.fromList([0, 1, 1, 0]),
  submittedAt: t0,
  mine: mine,
  myScore: myScore,
  rank: rank,
  score: score,
  voteCount: rank == null ? null : 4,
);

GalleryShopItem shopItemOf(
  int rank, {
  bool owned = false,
  int? stock = 100,
  int sold = 0,
}) => GalleryShopItem(
  id: 'contest_e$rank',
  title: 'Group $rank',
  rarity: rank == 1 ? Rarity.legendary : Rarity.rare,
  theme: CosmeticTheme.vanGogh,
  price: const [300, 220, 150][rank - 1],
  rank: rank,
  weekKey: '2026-W40',
  titleVi: 'Hoa hướng dương',
  titleEn: 'Sunflowers',
  owned: owned,
  stock: stock,
  sold: sold,
);

BannerArt bannerArtOf() => BannerArt(
  width: 2,
  height: 2,
  palette: const [0xFF000000, 0xFFFF0000],
  pixels: Uint8List.fromList([0, 1, 1, 0]),
  groupName: 'Painters',
);

ContestInfo contestInfo({
  ContestPhase phase = ContestPhase.open,
  int accepted = 5,
  Duration opensIn = const Duration(hours: -1),
  Duration closesIn = const Duration(hours: 20),
  Duration endsIn = const Duration(hours: 30),
}) => ContestInfo(
  id: 'c1',
  weekKey: '2026-W41',
  phase: phase,
  startsAt: t0.add(const Duration(days: -5)),
  opensAt: t0.add(opensIn),
  submitClosesAt: t0.add(closesIn),
  endsAt: t0.add(endsIn),
  acceptedCount: accepted,
  maxEntries: 100,
);

const theme = ContestTheme(
  category: 'vangogh',
  titleVi: 'Đêm đầy sao',
  titleEn: 'The Starry Night',
  briefVi: 'Bầu trời xoáy.',
  briefEn: 'A swirling sky.',
  paletteId: 'vangogh',
);

ContestOverview overviewOf({
  ContestInfo? contest,
  DateTime? serverNow,
  bool participant = false,
  List<OwnedGroup> owned = const [],
  MyEntry? mine,
  int myVotes = 0,
  int votesNeeded = 0,
  PreviousContest? previous,
}) => ContestOverview(
  contest: contest ?? contestInfo(),
  theme: theme,
  serverNow: serverNow ?? t0,
  participant: participant,
  myEntry: mine,
  ownerGroups: owned,
  myVotes: myVotes,
  votesNeeded: votesNeeded,
  previous: previous,
);

/// In-memory contest server for tests.
class FakeContest implements ContestRepository {
  FakeContest({this.current});

  ContestOverview? current;
  final List<GalleryEntry> entries = [];
  final List<EntryComment> commentList = [];
  final calls = <String>[];
  ContestFailure? failNext;
  ContestFailure? failOverview;
  EntryDetail? detail;
  ContestResults? resultsOf;
  final List<GalleryEntry> hall = [];
  final List<GalleryShopItem> shop = [];
  final Map<String, BannerArt> art = {};
  int shopLoads = 0;
  int artLoads = 0;
  final _changes = StreamController<void>.broadcast();
  int pageLoads = 0;

  void pushChange() => _changes.add(null);

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void dispose() => _changes.close();

  @override
  Future<ContestOverview?> overview() async {
    calls.add('overview');
    final failure = failOverview;
    if (failure != null) throw failure;
    return current;
  }

  @override
  Future<int> submit(String groupId, {String? contestId}) async {
    calls.add('submit:$groupId:$contestId');
    _maybeFail();
    return 7;
  }

  @override
  Future<GalleryPage> gallery({
    String? contestId,
    int after = 0,
    int limit = 20,
  }) async {
    pageLoads++;
    _maybeFail();
    final page = entries.where((e) => e.seq > after).take(limit).toList();
    return GalleryPage(
      contestId: 'c1',
      phase: ContestPhase.judging,
      entries: page,
      nextAfter: page.length == limit ? page.last.seq : null,
    );
  }

  @override
  Future<EntryDetail> entry(String entryId) async {
    _maybeFail();
    return detail ??
        EntryDetail(
          entry: entries.firstWhere((e) => e.id == entryId),
          phase: ContestPhase.judging,
          participant: true,
          reactions: const {},
          commentCount: commentList.length,
        );
  }

  @override
  Future<List<EntryComment>> comments(
    String entryId, {
    DateTime? before,
  }) async => List.of(commentList);

  @override
  Future<void> vote(String entryId, int score) async {
    calls.add('vote:$entryId:$score');
    _maybeFail();
  }

  @override
  Future<void> react(String entryId, String? emoji) async {
    calls.add('react:$entryId:$emoji');
    _maybeFail();
  }

  @override
  Future<void> comment(String entryId, String body) async {
    calls.add('comment:$entryId:$body');
    _maybeFail();
    commentList.insert(
      0,
      EntryComment(
        id: 'k${commentList.length}',
        authorId: 'me',
        authorName: 'Me',
        body: body,
        createdAt: t0,
        mine: true,
      ),
    );
  }

  @override
  Future<void> report({
    String? entryId,
    String? commentId,
    required ReportReasonKind reason,
    String? details,
  }) async {
    calls.add('report:${entryId ?? commentId}:${reason.name}');
    _maybeFail();
  }

  @override
  Future<ContestResults> results(String contestId) async =>
      resultsOf ??
      ContestResults(
        contestId: contestId,
        weekKey: '2026-W40',
        phase: ContestPhase.finalized,
        titleVi: 'Hoa hướng dương',
        titleEn: 'Sunflowers',
        entryCount: 3,
        winners: [
          entryOf(2, rank: 1, score: 3.72),
          entryOf(1, rank: 2, score: 3.5),
        ],
      );

  @override
  Future<List<GalleryEntry>> hallOfFame({
    int offset = 0,
    int limit = 12,
  }) async {
    _maybeFail();
    return hall.skip(offset).take(limit).toList();
  }

  @override
  Future<List<GalleryShopItem>> shopItems() async {
    shopLoads++;
    _maybeFail();
    return List.of(shop);
  }

  @override
  Future<BannerArt> bannerArt(String itemId) async {
    artLoads++;
    final found = art[itemId];
    if (found == null) throw const ContestFailure(ContestFailureKind.notFound);
    return found;
  }
}

void main() {
  group('parsing', () {
    test('an overview from the server', () {
      final overview = ContestOverview.fromJson({
        'server_now': '2026-10-10T12:00:00Z',
        'contest': {
          'id': 'c1',
          'week_key': '2026-W41',
          'phase': 'judging',
          'starts_at': '2026-10-04T17:00:00Z',
          'opens_at': '2026-10-09T17:00:00Z',
          'submit_closes_at': '2026-10-11T05:00:00Z',
          'ends_at': '2026-10-11T17:00:00Z',
          'accepted_count': 87,
          'max_entries': 100,
        },
        'theme': {
          'category': '8bit',
          'title_vi': 'Máy arcade',
          'title_en': 'Arcade',
          'brief_vi': 'a',
          'brief_en': 'b',
          'palette_id': 'eightbit',
        },
        'participant': true,
        'my_entry': {'id': 'e1', 'seq': 12, 'group_name': 'Team'},
        'owner_groups': [
          {'id': 'g1', 'name': 'Team', 'submitted': true},
          {'id': 'g2', 'name': 'Other', 'submitted': false},
        ],
        'my_votes': 3,
        'votes_needed': 10,
        'previous': {
          'id': 'c0',
          'week_key': '2026-W40',
          'title_vi': 'x',
          'title_en': 'y',
        },
      })!;
      expect(overview.contest.phase, ContestPhase.judging);
      expect(overview.contest.acceptedCount, 87);
      expect(overview.theme.category, '8bit');
      expect(overview.myEntry?.seq, 12);
      expect(overview.ownerGroups.map((g) => g.submitted), [true, false]);
      expect(overview.votesNeeded, 10);
      expect(overview.previous?.id, 'c0');
    });

    test('no contest yet gives null', () {
      expect(ContestOverview.fromJson({'contest': null}), isNull);
    });

    test('an entry whose base64 Postgres wrapped over lines', () {
      final bytes = Uint8List.fromList([for (var i = 0; i < 1024; i++) i % 16]);
      final plain = base64Encode(bytes);
      final wrapped = '${plain.substring(0, 76)}\n${plain.substring(76)}';
      final entry = GalleryEntry.fromJson({
        'id': 'e1',
        'contest_id': 'c1',
        'seq': 1,
        'group_name': 'G',
        'width': 32,
        'height': 32,
        'palette': ['#000000', '#FF0000'],
        'pixels': wrapped,
        'submitted_at': '2026-10-10T12:00:00Z',
        'mine': true,
        'my_score': 4,
        'rank': 2,
        'score': 3.5,
        'vote_count': 4,
      });
      expect(entry.pixels, bytes);
      expect(entry.mine, isTrue);
      expect(entry.myScore, 4);
      expect(entry.rank, 2);
      expect(entry.palette.last, 0xFFFF0000);
    });

    test('a page with no next page', () {
      final page = GalleryPage.fromJson({
        'contest_id': 'c1',
        'phase': 'open',
        'entries': <dynamic>[],
        'next_after': null,
      });
      expect(page.nextAfter, isNull);
      expect(page.phase, ContestPhase.open);
    });
  });

  group('ContestStore', () {
    test('follows the server clock, not the phone clock', () async {
      // The phone says it is 3 days later than it really is.
      final repo = FakeContest(
        current: overviewOf(
          contest: contestInfo(
            opensIn: const Duration(hours: 5), // opens 5 hours after server now
            closesIn: const Duration(hours: 40),
            endsIn: const Duration(hours: 50),
            accepted: 0,
          ),
          serverNow: t0,
        ),
      );
      final phone = t0.add(const Duration(days: 3));
      final store = ContestStore(repo, clock: () => phone);
      await store.refresh();
      expect(store.now, t0);
      expect(store.phase, ContestPhase.upcoming);
      expect(store.timeLeft, const Duration(hours: 5));
      expect(store.nextMilestone?.phase, ContestPhase.open);
      store.dispose();
    });

    test('moves through the phases as the clock passes', () async {
      var phone = t0;
      final repo = FakeContest(current: overviewOf(serverNow: t0));
      final store = ContestStore(repo, clock: () => phone);
      await store.refresh();
      expect(store.phase, ContestPhase.open);
      phone = t0.add(const Duration(hours: 21)); // past submitClosesAt (+20h)
      expect(store.phase, ContestPhase.judging);
      expect(store.nextMilestone?.phase, ContestPhase.closed);
      phone = t0.add(const Duration(hours: 31)); // past endsAt (+30h)
      expect(store.phase, ContestPhase.closed);
      expect(store.nextMilestone, isNull);
      expect(store.timeLeft, isNull);
      store.dispose();
    });

    test('a full contest is judging even before the deadline', () async {
      final repo = FakeContest(
        current: overviewOf(contest: contestInfo(accepted: 100)),
      );
      final store = ContestStore(repo, clock: () => t0);
      await store.refresh();
      expect(store.phase, ContestPhase.judging);
      store.dispose();
    });

    test(
      'only groups I own and that have not entered can submit, while open',
      () async {
        final repo = FakeContest(
          current: overviewOf(
            owned: const [
              OwnedGroup(id: 'g1', name: 'A', submitted: true),
              OwnedGroup(id: 'g2', name: 'B', submitted: false),
            ],
          ),
        );
        final store = ContestStore(repo, clock: () => t0);
        await store.refresh();
        expect(store.submittableGroups.map((g) => g.id), ['g2']);
        repo.current = overviewOf(
          contest: contestInfo(opensIn: const Duration(hours: 4)),
          owned: const [OwnedGroup(id: 'g2', name: 'B', submitted: false)],
        );
        await store.refresh();
        expect(store.submittableGroups, isEmpty);
        store.dispose();
      },
    );

    test(
      'submitting returns the place and reloads, also after a refusal',
      () async {
        final repo = FakeContest(
          current: overviewOf(
            owned: const [OwnedGroup(id: 'g1', name: 'A', submitted: false)],
          ),
        );
        final store = ContestStore(repo, clock: () => t0);
        await store.refresh();
        final before = repo.calls.where((c) => c == 'overview').length;
        expect(await store.submit(store.submittableGroups.single), 7);
        expect(repo.calls, contains('submit:g1:c1'));
        expect(
          repo.calls.where((c) => c == 'overview').length,
          greaterThan(before),
        );
        repo.failNext = const ContestFailure(ContestFailureKind.contestFull);
        final mid = repo.calls.where((c) => c == 'overview').length;
        await expectLater(
          store.submit(const OwnedGroup(id: 'g1', name: 'A', submitted: false)),
          throwsA(isA<ContestFailure>()),
        );
        expect(
          repo.calls.where((c) => c == 'overview').length,
          greaterThan(mid),
        );
        store.dispose();
      },
    );

    test('a failed refresh keeps what was shown', () async {
      final repo = FakeContest(current: overviewOf());
      final store = ContestStore(repo, clock: () => t0);
      await store.refresh();
      repo.failOverview = const ContestFailure(ContestFailureKind.network);
      await store.refresh();
      expect(store.error?.kind, ContestFailureKind.network);
      expect(store.contest?.weekKey, '2026-W41');
      expect(store.isLoaded, isTrue);
      store.dispose();
    });

    test('a change from the server (a new entry) reloads by itself', () async {
      final repo = FakeContest(current: overviewOf());
      final store = ContestStore(repo, clock: () => t0);
      await store.refresh();
      repo.current = overviewOf(contest: contestInfo(accepted: 6));
      repo.pushChange();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.contest?.acceptedCount, 6);
      store.dispose();
    });
  });

  group('GalleryStore', () {
    FakeContest manyEntries(int n) {
      final repo = FakeContest();
      for (var i = 1; i <= n; i++) {
        repo.entries.add(entryOf(i));
      }
      return repo;
    }

    test('loads a page at a time in the order they were accepted', () async {
      final repo = manyEntries(45);
      final store = GalleryStore(repo, pageSize: 20);
      await store.load();
      expect(store.entries.length, 20);
      expect(store.hasMore, isTrue);
      await store.loadMore();
      await store.loadMore();
      expect(store.entries.map((e) => e.seq), [
        for (var i = 1; i <= 45; i++) i,
      ]);
      expect(store.hasMore, isFalse);
      expect(repo.pageLoads, 3);
      await store.loadMore(); // nothing left: no request
      expect(repo.pageLoads, 3);
    });

    test(
      'asking twice at once loads one page, and never repeats an entry',
      () async {
        final repo = manyEntries(30);
        final store = GalleryStore(repo, pageSize: 20);
        await store.load();
        await Future.wait([store.loadMore(), store.loadMore()]);
        expect(repo.pageLoads, 2);
        expect(store.entries.length, 30);
      },
    );

    test('a failed page keeps the entries and can be retried', () async {
      final repo = manyEntries(30);
      final store = GalleryStore(repo, pageSize: 20);
      await store.load();
      repo.failNext = const ContestFailure(ContestFailureKind.network);
      await store.loadMore();
      expect(store.error?.kind, ContestFailureKind.network);
      expect(store.entries.length, 20);
      await store.loadMore();
      expect(store.error, isNull);
      expect(store.entries.length, 30);
    });

    test('a rating made on the detail screen shows in the list', () async {
      final repo = manyEntries(3);
      final store = GalleryStore(repo);
      await store.load();
      store.replace(store.entries[1].copyWith(myScore: 5));
      expect(store.entries[1].myScore, 5);
      expect(store.entries[0].myScore, isNull);
    });
  });

  group('EntryStore', () {
    Future<(FakeContest, EntryStore)> open({
      bool participant = true,
      ContestPhase phase = ContestPhase.judging,
      bool mine = false,
    }) async {
      final entry = entryOf(3, mine: mine);
      final repo = FakeContest()
        ..entries.add(entry)
        ..detail = EntryDetail(
          entry: entry,
          phase: phase,
          participant: participant,
          reactions: const {'🔥': 2},
          commentCount: 0,
        );
      final store = EntryStore(repo, entry);
      await store.load();
      return (repo, store);
    }

    test('a participant can rate and comment while rating is open', () async {
      final (_, store) = await open();
      expect(store.canRate, isTrue);
      expect(store.canComment, isTrue);
      expect(store.reactions, {'🔥': 2});
    });

    test('nobody can rate their own group or before/after rating', () async {
      expect((await open(mine: true)).$2.canRate, isFalse);
      expect((await open(mine: true)).$2.canComment, isTrue);
      expect((await open(participant: false)).$2.canRate, isFalse);
      expect((await open(participant: false)).$2.canComment, isFalse);
      expect((await open(phase: ContestPhase.finalized)).$2.canRate, isFalse);
      expect((await open(phase: ContestPhase.open)).$2.canComment, isFalse);
    });

    test('a rating shows at once and is sent', () async {
      final (repo, store) = await open();
      final done = store.rate(4);
      expect(store.entry.myScore, 4);
      await done;
      expect(repo.calls, ['vote:e3:4']);
    });

    test('a refused rating goes back to the old one', () async {
      final (repo, store) = await open();
      await store.rate(2);
      repo.failNext = const ContestFailure(ContestFailureKind.notJudging);
      await expectLater(store.rate(5), throwsA(isA<ContestFailure>()));
      expect(store.entry.myScore, 2);
    });

    test('a comment is stored and listed', () async {
      final (repo, store) = await open();
      await store.comment('  Love it  ');
      expect(repo.calls, ['comment:e3:Love it']);
      expect(store.comments.single.body, 'Love it');
      expect(store.comments.single.mine, isTrue);
      await store.comment('   ');
      expect(repo.calls.length, 1);
    });

    test('a refused comment throws and nothing is added', () async {
      final (repo, store) = await open();
      repo.failNext = const ContestFailure(ContestFailureKind.tooFast);
      await expectLater(store.comment('hi'), throwsA(isA<ContestFailure>()));
      expect(store.comments, isEmpty);
      expect(store.sending, isFalse);
    });

    test('reporting a comment takes it off my screen', () async {
      final (repo, store) = await open();
      await store.comment('rude');
      final comment = store.comments.single;
      await store.reportComment(comment, ReportReasonKind.harassment);
      expect(repo.calls.last, 'report:${comment.id}:harassment');
      expect(store.comments, isEmpty);
    });

    test('tapping my reaction again takes it back', () async {
      final (repo, store) = await open();
      await store.react('🎨');
      expect(repo.calls.last, 'react:e3:🎨');
    });
  });

  group('corridor geometry', () {
    bool suits(FrameSlot s) =>
        math.min(s.width, s.height) >= 0.89 &&
        s.width / s.height >= 0.65 &&
        s.width / s.height <= 1.55;

    test('the wall is the same every time and every entry has one frame', () {
      final a = layoutGallery(100);
      final b = layoutGallery(100);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].z0, b[i].z0);
        expect(a[i].yTop, b[i].yTop);
        expect(a[i].index, b[i].index);
        expect(a[i].style, b[i].style);
      }
      final entries = [
        for (final s in a)
          if (!s.isBlank) s.index,
      ];
      expect(entries.toSet(), {for (var i = 0; i < 100; i++) i});
      expect(entries.length, 100);
    });

    test(
      'with no entry the corridor still has walls full of blank canvases',
      () {
        final slots = layoutGallery(0);
        expect(slots.every((s) => s.isBlank), isTrue);
        expect(slots.where(suits).length, greaterThanOrEqualTo(36));
        expect(slots.any((s) => s.side < 0), isTrue);
        expect(slots.any((s) => s.side > 0), isTrue);
        expect(corridorLength(slots), greaterThan(20));
      },
    );

    test('entries hang from the entrance outwards, in the order accepted', () {
      final slots = layoutGallery(60).where((s) => !s.isBlank).toList()
        ..sort((x, y) => x.index.compareTo(y.index));
      for (var i = 1; i < slots.length; i++) {
        final before = slots[i - 1], after = slots[i];
        expect(
          after.z0 > before.z0 ||
              (after.z0 == before.z0 && after.side >= before.side),
          isTrue,
          reason: 'entry $i hangs before entry ${i - 1}',
        );
      }
      // Both walls get paintings.
      expect(slots.any((s) => s.side < 0), isTrue);
      expect(slots.any((s) => s.side > 0), isTrue);
    });

    test('a painting only goes in a frame that suits it', () {
      for (final slot in layoutGallery(100)) {
        if (!slot.isBlank) expect(suits(slot), isTrue);
      }
    });

    test('there is always more wall after the last entry', () {
      for (final n in [0, 1, 7, 40, 100]) {
        final slots = layoutGallery(n);
        final free = slots.where((s) => s.isBlank && suits(s)).length;
        expect(free, greaterThanOrEqualTo(16), reason: '$n entries');
      }
    });

    test('no two frames on a wall overlap and none leaves the wall', () {
      final slots = layoutGallery(100);
      for (final slot in slots) {
        expect(slot.z0, greaterThanOrEqualTo(Corridor.startZ));
        expect(slot.yTop, greaterThanOrEqualTo(Corridor.wallTop - 1e-9));
        expect(slot.yBottom, lessThanOrEqualTo(Corridor.wallBottom + 1e-9));
        expect(slot.size, greaterThan(0));
      }
      for (var i = 0; i < slots.length; i++) {
        for (var j = i + 1; j < slots.length; j++) {
          final a = slots[i], b = slots[j];
          if (a.side != b.side) continue;
          final zOverlap = a.z0 < b.z1 - 1e-9 && b.z0 < a.z1 - 1e-9;
          final yOverlap =
              a.yTop < b.yBottom - 1e-9 && b.yTop < a.yBottom - 1e-9;
          expect(
            zOverlap && yOverlap,
            isFalse,
            reason: 'frames $i and $j overlap',
          );
        }
      }
    });

    test('the walls are covered like a salon wall, not dotted with frames', () {
      final slots = layoutGallery(60);
      const length = 20.0;
      for (final side in const [-1, 1]) {
        var framed = 0.0;
        for (final s in slots.where((s) => s.side == side && s.z1 <= length)) {
          framed += s.width * s.height;
        }
        const wall =
            (length - Corridor.startZ) *
            (Corridor.wallBottom - Corridor.wallTop);
        expect(framed / wall, greaterThan(0.5), reason: 'side $side');
      }
    });

    test('the frames come in many sizes, and some hang above one another', () {
      final slots = layoutGallery(100);
      final sizes = {
        for (final s in slots)
          '${s.width.toStringAsFixed(2)}x${s.height.toStringAsFixed(2)}',
      };
      expect(sizes.length, greaterThanOrEqualTo(6));
      var stacked = 0;
      for (final a in slots) {
        for (final b in slots) {
          if (identical(a, b) || a.side != b.side) continue;
          if (a.z0 == b.z0 && a.yBottom < b.yTop) stacked++;
        }
      }
      expect(stacked, greaterThan(0));
      expect({for (final s in slots) s.style}.length, greaterThanOrEqualTo(4));
    });

    test('more entries only add wall at the far end, the near wall stays', () {
      String key(FrameSlot s) =>
          '${s.side}:${s.z0.toStringAsFixed(3)}:${s.yTop.toStringAsFixed(3)}:${s.style}';
      final few = {
        for (final s in layoutGallery(5).where((s) => s.z1 < 18)) key(s),
      };
      final many = {
        for (final s in layoutGallery(90).where((s) => s.z1 < 18)) key(s),
      };
      expect(few, many);
    });

    test('a painting is a square in the middle of its frame', () {
      final view = Projection(const Size(400, 800), 0);
      final slot = layoutGallery(10).firstWhere((s) => !s.isBlank);
      final outer = view.wallQuad(slot)!;
      final art = view.artQuad(slot)!;
      final centre = Offset(
        art.map((p) => p.dx).reduce((x, y) => x + y) / 4,
        art.map((p) => p.dy).reduce((x, y) => x + y) / 4,
      );
      expect(pointInQuad(centre, outer), isTrue);
      for (final corner in art) {
        expect(pointInQuad(corner, outer), isTrue);
      }
    });

    test('a point far down the corridor lands on the vanishing point', () {
      final view = Projection(const Size(400, 800), 0);
      final far = view.point(1.6, 1.5, 1e6)!;
      expect((far - view.vanishingPoint).distance, lessThan(0.01));
      final centre = view.point(0, 0, 5)!;
      expect(centre, view.vanishingPoint);
    });

    test('things behind the visitor are not drawn', () {
      final view = Projection(const Size(400, 800), 10);
      expect(view.point(1, 0, 9), isNull);
      expect(view.point(1, 0, 10.1), isNull);
      expect(view.point(1, 0, 11), isNotNull);
    });

    test('nearer things are bigger', () {
      final view = Projection(const Size(400, 800), 0);
      final nearEdge = view.point(1.6, 0, 2)!.dx - view.cx;
      final farEdge = view.point(1.6, 0, 8)!.dx - view.cx;
      expect(nearEdge, greaterThan(farEdge * 3.9));
    });

    test('a frame on the left wall: its left edge is the near one', () {
      const slot = FrameSlot(
        index: 0,
        side: -1,
        z0: 3,
        z1: 4,
        yTop: -0.5,
        yBottom: 0.5,
      );
      final view = Projection(const Size(400, 800), 0);
      final quad = view.wallQuad(slot)!;
      // Top-left is nearer than top-right, so it is further from the centre.
      expect(
        (quad[0].dx - view.cx).abs(),
        greaterThan((quad[1].dx - view.cx).abs()),
      );
      // The wall is on the left of the centre.
      expect(quad[0].dx, lessThan(view.cx));
      // A frame is taller near the visitor than far away.
      expect(quad[3].dy - quad[0].dy, greaterThan(quad[2].dy - quad[1].dy));
    });

    test('a frame on the right wall is the mirror image', () {
      const left = FrameSlot(
        index: 0,
        side: -1,
        z0: 3,
        z1: 4,
        yTop: -0.5,
        yBottom: 0.5,
      );
      const right = FrameSlot(
        index: 1,
        side: 1,
        z0: 3,
        z1: 4,
        yTop: -0.5,
        yBottom: 0.5,
      );
      final view = Projection(const Size(400, 800), 0);
      final a = view.wallQuad(left)!;
      final b = view.wallQuad(right)!;
      // Seen in a mirror, top-left becomes top-right and bottom-left becomes
      // bottom-right: the near edge of both walls is the one nearest the visitor.
      const mirror = [1, 0, 3, 2];
      for (var i = 0; i < 4; i++) {
        expect(a[i].dx - view.cx, closeTo(-(b[mirror[i]].dx - view.cx), 1e-9));
        expect(a[i].dy, closeTo(b[mirror[i]].dy, 1e-9));
      }
    });

    test('the matrix maps the picture corners onto the frame corners', () {
      const slot = FrameSlot(
        index: 0,
        side: 1,
        z0: 3,
        z1: 4.4,
        yTop: -0.7,
        yBottom: 0.7,
      );
      final view = Projection(const Size(400, 800), 0);
      final quad = view.wallQuad(slot)!;
      final matrix = unitSquareToQuad(quad);
      const corners = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      for (var i = 0; i < 4; i++) {
        final p = applyToUnit(matrix, corners[i].dx, corners[i].dy);
        expect(p.dx, closeTo(quad[i].dx, 1e-6));
        expect(p.dy, closeTo(quad[i].dy, 1e-6));
      }
    });

    test('the middle of the picture is where perspective puts it', () {
      // On a wall, the middle of the picture in 3D is nearer than the middle of
      // the shape on screen: it must be on the near side of the screen middle.
      const slot = FrameSlot(
        index: 0,
        side: -1,
        z0: 3,
        z1: 6,
        yTop: -0.5,
        yBottom: 0.5,
      );
      final view = Projection(const Size(400, 800), 0);
      final quad = view.wallQuad(slot)!;
      final matrix = unitSquareToQuad(quad);
      final centre = applyToUnit(matrix, 0.5, 0.5);
      final truth = view.point(-Corridor.wallX, 0, 4.5)!;
      expect(centre.dx, closeTo(truth.dx, 1e-6));
      expect(centre.dy, closeTo(truth.dy, 1e-6));
      final naive = Offset(
        (quad[0].dx + quad[1].dx) / 2,
        (quad[0].dy + quad[3].dy) / 2,
      );
      expect((centre.dx - naive.dx).abs(), greaterThan(1));
    });

    test('a flat (parallel) quad still maps correctly', () {
      final matrix = unitSquareToQuad(const [
        Offset(10, 20),
        Offset(110, 20),
        Offset(110, 70),
        Offset(10, 70),
      ]);
      expect(applyToUnit(matrix, 0.5, 0.5), const Offset(60, 45));
    });

    test('point in quad, either winding', () {
      const quad = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)];
      expect(pointInQuad(const Offset(5, 5), quad), isTrue);
      expect(pointInQuad(const Offset(11, 5), quad), isFalse);
      expect(pointInQuad(const Offset(5, 5), quad.reversed.toList()), isTrue);
    });

    test('frames to draw: only what is ahead and in range, far ones first', () {
      final slots = layoutGallery(100);
      final visible = visibleSlots(slots, 20);
      for (final slot in visible) {
        expect(slot.z0 - 20, greaterThanOrEqualTo(Corridor.near));
        expect(slot.z0 - 20, lessThanOrEqualTo(Corridor.far));
      }
      for (var i = 1; i < visible.length; i++) {
        expect(visible[i - 1].z0, greaterThanOrEqualTo(visible[i].z0));
      }
      expect(visible, isNotEmpty);
    });

    test('a tap finds the frame under it, and nothing on the bare wall', () {
      final slots = layoutGallery(100);
      final view = Projection(const Size(400, 800), 0);
      final first = slots.firstWhere((s) => s.index == 0);
      final quad = view.wallQuad(first)!;
      final centre = Offset(
        quad.map((p) => p.dx).reduce((a, b) => a + b) / 4,
        quad.map((p) => p.dy).reduce((a, b) => a + b) / 4,
      );
      expect(hitTest(centre, slots, view)?.index, 0);
      // The middle of the floor has no frame.
      expect(hitTest(Offset(200, 790), slots, view), isNull);
      // A blank canvas has nothing to open.
      final blank = slots.firstWhere(
        (s) => s.isBlank && s.z0 > Corridor.startZ + 1,
      );
      final blankQuad = view.wallQuad(blank)!;
      final blankCentre = Offset(
        blankQuad.map((p) => p.dx).reduce((a, b) => a + b) / 4,
        blankQuad.map((p) => p.dy).reduce((a, b) => a + b) / 4,
      );
      expect(hitTest(blankCentre, slots, view)?.isBlank ?? true, isTrue);
    });

    test('the corridor is as long as its last frame', () {
      final slots = layoutGallery(100);
      expect(
        corridorLength(slots),
        slots.map((s) => s.z1).reduce((a, b) => a > b ? a : b),
      );
      expect(corridorLength(const []), Corridor.startZ);
    });
  });

  group('entry pictures', () {
    test('cells become RGBA bytes through the palette', () {
      final rgba = rgbaOf(entryOf(1));
      expect(rgba.length, 16);
      expect(rgba.sublist(0, 4), [0, 0, 0, 255]); // black
      expect(rgba.sublist(4, 8), [255, 0, 0, 255]); // red
    });

    test('the average colour sits between the colours used', () {
      final average = averageArgb(entryOf(1)); // half black, half red
      expect((average >> 16) & 0xFF, 127);
      expect((average >> 8) & 0xFF, 0);
      expect(average >> 24, 0xFF);
    });

    testWidgets('the cache keeps at most its capacity, oldest first', (
      tester,
    ) async {
      final cache = EntryImageCache(capacity: 2);
      await tester.runAsync(() async {
        await cache.load(entryOf(1));
        await cache.load(entryOf(2));
        expect(cache.length, 2);
        expect(cache.peek('e1'), isNotNull); // touching e1 makes e2 the oldest
        await cache.load(entryOf(3));
      });
      expect(cache.length, 2);
      expect(cache.peek('e2'), isNull);
      expect(cache.peek('e1'), isNotNull);
      expect(cache.peek('e3'), isNotNull);
      await tester.pump();
      cache.dispose();
    });

    testWidgets('asking for the same picture twice decodes it once', (
      tester,
    ) async {
      var decodes = 0;
      final cache = EntryImageCache(
        decoder: (rgba, w, h) {
          decodes++;
          return decodeRgba(rgba, w, h);
        },
      );
      await tester.runAsync(() async {
        await Future.wait([cache.load(entryOf(1)), cache.load(entryOf(1))]);
        await cache.load(entryOf(1));
      });
      expect(decodes, 1);
      cache.dispose();
    });
  });
}
