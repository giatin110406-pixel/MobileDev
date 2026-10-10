import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart'
    show parseHexColor;
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum ContestPhase { upcoming, open, judging, closed, finalized }

ContestPhase _phaseOf(Object? value) => switch (value) {
  'open' => ContestPhase.open,
  'judging' => ContestPhase.judging,
  'closed' => ContestPhase.closed,
  'finalized' => ContestPhase.finalized,
  _ => ContestPhase.upcoming,
};

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();

/// One week's contest and where it stands.
class ContestInfo {
  const ContestInfo({
    required this.id,
    required this.weekKey,
    required this.phase,
    required this.startsAt,
    required this.opensAt,
    required this.submitClosesAt,
    required this.endsAt,
    required this.acceptedCount,
    required this.maxEntries,
  });

  final String id;
  final String weekKey;
  final ContestPhase phase;
  final DateTime startsAt;

  /// Saturday 00:00 Vietnam time: submissions open.
  final DateTime opensAt;

  /// Sunday 12:00: submissions end and rating starts, if the contest has not
  /// filled up before.
  final DateTime submitClosesAt;

  /// The next Monday 00:00 (Sunday 23:59:59 is the last moment).
  final DateTime endsAt;
  final int acceptedCount;
  final int maxEntries;

  bool get isFull => acceptedCount >= maxEntries;

  factory ContestInfo.fromJson(Map<String, dynamic> json) => ContestInfo(
    id: json['id'] as String,
    weekKey: json['week_key'] as String,
    phase: _phaseOf(json['phase'] ?? json['status']),
    startsAt: _time(json['starts_at']),
    opensAt: _time(json['opens_at']),
    submitClosesAt: _time(json['submit_closes_at']),
    endsAt: _time(json['ends_at']),
    acceptedCount: json['accepted_count'] as int? ?? 0,
    maxEntries: json['max_entries'] as int? ?? 100,
  );

  ContestInfo copyWith({int? acceptedCount, ContestPhase? phase}) =>
      ContestInfo(
        id: id,
        weekKey: weekKey,
        phase: phase ?? this.phase,
        startsAt: startsAt,
        opensAt: opensAt,
        submitClosesAt: submitClosesAt,
        endsAt: endsAt,
        acceptedCount: acceptedCount ?? this.acceptedCount,
        maxEntries: maxEntries,
      );
}

class ContestTheme {
  const ContestTheme({
    required this.category,
    required this.titleVi,
    required this.titleEn,
    required this.briefVi,
    required this.briefEn,
    required this.paletteId,
  });

  /// '8bit' or 'vangogh'.
  final String category;
  final String titleVi;
  final String titleEn;
  final String briefVi;
  final String briefEn;
  final String paletteId;

  String title({required bool vietnamese}) => vietnamese ? titleVi : titleEn;
  String brief({required bool vietnamese}) => vietnamese ? briefVi : briefEn;

  factory ContestTheme.fromJson(Map<String, dynamic> json) => ContestTheme(
    category: json['category'] as String,
    titleVi: json['title_vi'] as String,
    titleEn: json['title_en'] as String,
    briefVi: json['brief_vi'] as String,
    briefEn: json['brief_en'] as String,
    paletteId: json['palette_id'] as String,
  );
}

/// A group I own, and whether it has already entered this contest.
class OwnedGroup {
  const OwnedGroup({
    required this.id,
    required this.name,
    required this.submitted,
  });

  final String id;
  final String name;
  final bool submitted;
}

class MyEntry {
  const MyEntry({required this.id, required this.seq, required this.groupName});

  final String id;
  final int seq;
  final String groupName;
}

class PreviousContest {
  const PreviousContest({
    required this.id,
    required this.weekKey,
    required this.titleVi,
    required this.titleEn,
  });

  final String id;
  final String weekKey;
  final String titleVi;
  final String titleEn;
}

/// Everything the contest screen shows, from one call.
class ContestOverview {
  const ContestOverview({
    required this.contest,
    required this.theme,
    required this.serverNow,
    this.participant = false,
    this.myEntry,
    this.ownerGroups = const [],
    this.myVotes = 0,
    this.votesNeeded = 0,
    this.previous,
  });

  final ContestInfo contest;
  final ContestTheme theme;
  final DateTime serverNow;

  /// My group (or one I am in) entered: I may rate and comment.
  final bool participant;
  final MyEntry? myEntry;
  final List<OwnedGroup> ownerGroups;

  /// How many entries I have rated, and how many my ratings need to count.
  final int myVotes;
  final int votesNeeded;
  final PreviousContest? previous;

  ContestOverview copyWith({ContestInfo? contest}) => ContestOverview(
    contest: contest ?? this.contest,
    theme: theme,
    serverNow: serverNow,
    participant: participant,
    myEntry: myEntry,
    ownerGroups: ownerGroups,
    myVotes: myVotes,
    votesNeeded: votesNeeded,
    previous: previous,
  );

  /// Null when the server has no contest yet.
  static ContestOverview? fromJson(Map<String, dynamic> json) {
    final contest = json['contest'];
    if (contest == null) return null;
    final entry = json['my_entry'] as Map<String, dynamic>?;
    final previous = json['previous'] as Map<String, dynamic>?;
    return ContestOverview(
      contest: ContestInfo.fromJson(contest as Map<String, dynamic>),
      theme: ContestTheme.fromJson(json['theme'] as Map<String, dynamic>),
      serverNow: _time(json['server_now']),
      participant: json['participant'] as bool? ?? false,
      myEntry: entry == null
          ? null
          : MyEntry(
              id: entry['id'] as String,
              seq: entry['seq'] as int,
              groupName: entry['group_name'] as String,
            ),
      ownerGroups: [
        for (final group in json['owner_groups'] as List<dynamic>? ?? const [])
          OwnedGroup(
            id: (group as Map<String, dynamic>)['id'] as String,
            name: group['name'] as String,
            submitted: group['submitted'] as bool? ?? false,
          ),
      ],
      myVotes: json['my_votes'] as int? ?? 0,
      votesNeeded: json['votes_needed'] as int? ?? 0,
      previous: previous == null
          ? null
          : PreviousContest(
              id: previous['id'] as String,
              weekKey: previous['week_key'] as String,
              titleVi: previous['title_vi'] as String,
              titleEn: previous['title_en'] as String,
            ),
    );
  }
}

/// A submitted canvas: a snapshot, so it never changes.
class GalleryEntry {
  const GalleryEntry({
    required this.id,
    required this.contestId,
    required this.seq,
    required this.groupName,
    required this.width,
    required this.height,
    required this.palette,
    required this.pixels,
    required this.submittedAt,
    this.mine = false,
    this.myScore,
    this.myEmoji,
    this.rank,
    this.score,
    this.voteCount,
    this.weekKey,
    this.titleVi,
    this.titleEn,
  });

  final String id;
  final String contestId;

  /// 1..100, the order the server accepted the entries.
  final int seq;
  final String groupName;
  final int width;
  final int height;

  /// ARGB colours; a cell is an index into this list.
  final List<int> palette;
  final Uint8List pixels;
  final DateTime submittedAt;

  /// This entry is from a group I am in (I cannot rate it).
  final bool mine;
  final int? myScore;
  final String? myEmoji;

  /// Set once the contest is finalized and only for the top 3.
  final int? rank;
  final double? score;
  final int? voteCount;

  /// Only in the Hall of Fame list.
  final String? weekKey;
  final String? titleVi;
  final String? titleEn;

  GalleryEntry copyWith({
    int? myScore,
    String? myEmoji,
    bool clearEmoji = false,
  }) => GalleryEntry(
    id: id,
    contestId: contestId,
    seq: seq,
    groupName: groupName,
    width: width,
    height: height,
    palette: palette,
    pixels: pixels,
    submittedAt: submittedAt,
    mine: mine,
    myScore: myScore ?? this.myScore,
    myEmoji: clearEmoji ? null : myEmoji ?? this.myEmoji,
    rank: rank,
    score: score,
    voteCount: voteCount,
    weekKey: weekKey,
    titleVi: titleVi,
    titleEn: titleEn,
  );

  factory GalleryEntry.fromJson(Map<String, dynamic> json) => GalleryEntry(
    id: json['id'] as String,
    contestId: json['contest_id'] as String,
    seq: json['seq'] as int,
    groupName: json['group_name'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
    palette: [
      for (final hex in json['palette'] as List<dynamic>) parseHexColor('$hex'),
    ],
    // Postgres may wrap base64 over several lines; Dart refuses the breaks.
    pixels: base64Decode(
      (json['pixels'] as String).replaceAll(RegExp(r'\s'), ''),
    ),
    submittedAt: _time(json['submitted_at']),
    mine: json['mine'] as bool? ?? false,
    myScore: json['my_score'] as int?,
    myEmoji: json['my_emoji'] as String?,
    rank: json['rank'] as int?,
    score: (json['score'] as num?)?.toDouble(),
    voteCount: json['vote_count'] as int?,
    weekKey: json['week_key'] as String?,
    titleVi: json['title_vi'] as String?,
    titleEn: json['title_en'] as String?,
  );
}

class GalleryPage {
  const GalleryPage({
    required this.contestId,
    required this.phase,
    required this.entries,
    this.nextAfter,
  });

  final String contestId;
  final ContestPhase phase;
  final List<GalleryEntry> entries;

  /// Pass this as `after` to get the next page; null when this was the last.
  final int? nextAfter;

  factory GalleryPage.fromJson(Map<String, dynamic> json) => GalleryPage(
    contestId: json['contest_id'] as String,
    phase: _phaseOf(json['phase']),
    entries: [
      for (final row in json['entries'] as List<dynamic>)
        GalleryEntry.fromJson(row as Map<String, dynamic>),
    ],
    nextAfter: json['next_after'] as int?,
  );
}

class EntryDetail {
  const EntryDetail({
    required this.entry,
    required this.phase,
    required this.participant,
    required this.reactions,
    required this.commentCount,
  });

  final GalleryEntry entry;
  final ContestPhase phase;
  final bool participant;
  final Map<String, int> reactions;
  final int commentCount;

  factory EntryDetail.fromJson(Map<String, dynamic> json) => EntryDetail(
    entry: GalleryEntry.fromJson(json),
    phase: _phaseOf(json['phase']),
    participant: json['participant'] as bool? ?? false,
    reactions: {
      for (final item
          in (json['reactions'] as Map<String, dynamic>? ?? const {}).entries)
        item.key: (item.value as num).toInt(),
    },
    commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
  );
}

class EntryComment {
  const EntryComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final bool mine;

  factory EntryComment.fromJson(Map<String, dynamic> json) => EntryComment(
    id: json['id'] as String,
    authorId: json['author_id'] as String,
    authorName: json['author_name'] as String? ?? '?',
    body: json['body'] as String,
    createdAt: _time(json['created_at']),
    mine: json['mine'] as bool? ?? false,
  );
}

class ContestResults {
  const ContestResults({
    required this.contestId,
    required this.weekKey,
    required this.phase,
    required this.titleVi,
    required this.titleEn,
    required this.entryCount,
    required this.winners,
  });

  final String contestId;
  final String weekKey;
  final ContestPhase phase;
  final String titleVi;
  final String titleEn;
  final int entryCount;

  /// Rank 1 first; fewer than 3 when too few entries had enough ratings.
  final List<GalleryEntry> winners;

  factory ContestResults.fromJson(Map<String, dynamic> json) => ContestResults(
    contestId: json['contest_id'] as String,
    weekKey: json['week_key'] as String,
    phase: _phaseOf(json['phase']),
    titleVi: json['title_vi'] as String,
    titleEn: json['title_en'] as String,
    entryCount: json['entry_count'] as int? ?? 0,
    winners: [
      for (final row in json['winners'] as List<dynamic>)
        GalleryEntry.fromJson(row as Map<String, dynamic>),
    ],
  );
}

/// A winning painting for sale in the shop, as a profile banner.
class GalleryShopItem {
  const GalleryShopItem({
    required this.id,
    required this.title,
    required this.rarity,
    required this.theme,
    required this.price,
    required this.rank,
    required this.weekKey,
    required this.titleVi,
    required this.titleEn,
    required this.owned,
    this.stock,
    this.sold = 0,
  });

  final String id;

  /// The name of the group that painted it.
  final String title;
  final Rarity rarity;
  final CosmeticTheme theme;
  final int price;
  final int rank;
  final String weekKey;
  final String titleVi;
  final String titleEn;
  final bool owned;

  /// Null = no limit.
  final int? stock;
  final int sold;

  int? get left => stock == null ? null : stock! - sold;
  bool get soldOut => left != null && left! <= 0;

  /// The same thing as the fixed shop's items, so the buy / equip logic is shared.
  ShopItem toShopItem() => ShopItem(
    id: id,
    name: title,
    kind: CosmeticKind.banner,
    rarity: rarity,
    theme: theme,
    price: price,
  );

  factory GalleryShopItem.fromJson(Map<String, dynamic> json) =>
      GalleryShopItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '?',
        rarity: switch (json['rarity']) {
          'legendary' => Rarity.legendary,
          'rare' => Rarity.rare,
          _ => Rarity.common,
        },
        theme: json['theme'] == 'vanGogh'
            ? CosmeticTheme.vanGogh
            : CosmeticTheme.pixel,
        price: json['price'] as int,
        rank: json['rank'] as int? ?? 3,
        weekKey: json['week_key'] as String? ?? '',
        titleVi: json['title_vi'] as String? ?? '',
        titleEn: json['title_en'] as String? ?? '',
        owned: json['owned'] as bool? ?? false,
        stock: json['stock'] as int?,
        sold: json['sold'] as int? ?? 0,
      );
}

/// The picture behind a painting-banner.
class BannerArt {
  const BannerArt({
    required this.width,
    required this.height,
    required this.palette,
    required this.pixels,
    required this.groupName,
  });

  final int width;
  final int height;
  final List<int> palette;
  final Uint8List pixels;
  final String groupName;

  factory BannerArt.fromJson(Map<String, dynamic> json) => BannerArt(
    width: json['width'] as int,
    height: json['height'] as int,
    palette: [
      for (final hex in json['palette'] as List<dynamic>) parseHexColor('$hex'),
    ],
    pixels: base64Decode(
      (json['pixels'] as String).replaceAll(RegExp(r'\s'), ''),
    ),
    groupName: json['group_name'] as String? ?? '',
  );
}

enum ReportReasonKind { spam, inappropriate, harassment, other }

enum ContestFailureKind {
  notFound,
  notOwner,
  notOpen,
  notJudging,
  alreadySubmitted,
  contestFull,
  canvasTooEmpty,
  groupTooSmall,
  noCanvas,
  notParticipant,
  ownEntry,
  badScore,
  empty,
  tooLong,
  tooFast,
  tooMany,
  blockedWord,
  tooManyReports,
  network,
  unknown,
}

class ContestFailure implements Exception {
  const ContestFailure(this.kind);

  final ContestFailureKind kind;

  @override
  String toString() => 'ContestFailure($kind)';
}

abstract interface class ContestRepository {
  /// This week's contest; null when the server has none yet.
  Future<ContestOverview?> overview();

  /// Enters [groupId]'s canvas (owner only). Returns the place it got.
  Future<int> submit(String groupId, {String? contestId});

  Future<GalleryPage> gallery({
    String? contestId,
    int after = 0,
    int limit = 20,
  });

  Future<EntryDetail> entry(String entryId);

  Future<List<EntryComment>> comments(String entryId, {DateTime? before});

  Future<void> vote(String entryId, int score);

  /// A null [emoji] takes my reaction back.
  Future<void> react(String entryId, String? emoji);

  Future<void> comment(String entryId, String body);

  Future<void> report({
    String? entryId,
    String? commentId,
    required ReportReasonKind reason,
    String? details,
  });

  Future<ContestResults> results(String contestId);

  Future<List<GalleryEntry>> hallOfFame({int offset = 0, int limit = 12});

  /// The winning paintings on sale in the shop.
  Future<List<GalleryShopItem>> shopItems();

  /// The picture of a painting-banner (for drawing it on a profile).
  Future<BannerArt> bannerArt(String itemId);

  /// Fires when the contest row changes (a new entry, a new phase).
  Stream<void> get changes;

  void dispose();
}

class SupabaseContestRepository implements ContestRepository {
  final _changes = StreamController<void>.broadcast();
  sb.RealtimeChannel? _channel;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Stream<void> get changes {
    _channel ??= _db
        .channel('contests')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.update,
          schema: 'public',
          table: 'contests',
          callback: (_) => _changes.add(null),
        )
        .subscribe();
    return _changes.stream;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _db.removeChannel(channel);
    _changes.close();
  }

  @override
  Future<ContestOverview?> overview() => _guard(() async {
    final json = await _db.rpc('get_current_contest');
    return ContestOverview.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<int> submit(String groupId, {String? contestId}) => _guard(() async {
    final json = await _db.rpc(
      'submit_entry',
      params: {'p_group': groupId, 'p_contest': contestId},
    );
    return (json as Map<String, dynamic>)['seq'] as int;
  });

  @override
  Future<GalleryPage> gallery({
    String? contestId,
    int after = 0,
    int limit = 20,
  }) => _guard(() async {
    final json = await _db.rpc(
      'get_gallery',
      params: {'p_contest': contestId, 'p_after': after, 'p_limit': limit},
    );
    return GalleryPage.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<EntryDetail> entry(String entryId) => _guard(() async {
    final json = await _db.rpc('get_entry', params: {'p_entry': entryId});
    return EntryDetail.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<List<EntryComment>> comments(String entryId, {DateTime? before}) =>
      _guard(() async {
        final rows = await _db.rpc(
          'get_entry_comments',
          params: {
            'p_entry': entryId,
            'p_before': before?.toUtc().toIso8601String(),
          },
        );
        return [
          for (final row in rows as List<dynamic>)
            EntryComment.fromJson(row as Map<String, dynamic>),
        ];
      });

  @override
  Future<void> vote(String entryId, int score) => _guard(
    () => _db.rpc('vote_entry', params: {'p_entry': entryId, 'p_score': score}),
  );

  @override
  Future<void> react(String entryId, String? emoji) => _guard(
    () =>
        _db.rpc('react_entry', params: {'p_entry': entryId, 'p_emoji': emoji}),
  );

  @override
  Future<void> comment(String entryId, String body) => _guard(
    () =>
        _db.rpc('comment_entry', params: {'p_entry': entryId, 'p_body': body}),
  );

  @override
  Future<void> report({
    String? entryId,
    String? commentId,
    required ReportReasonKind reason,
    String? details,
  }) => _guard(
    () => _db.rpc(
      'report_gallery',
      params: {
        'p_entry': entryId,
        'p_comment': commentId,
        'p_reason': reason.name,
        'p_details': details,
      },
    ),
  );

  @override
  Future<ContestResults> results(String contestId) => _guard(() async {
    final json = await _db.rpc(
      'get_contest_results',
      params: {'p_contest': contestId},
    );
    return ContestResults.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<List<GalleryEntry>> hallOfFame({int offset = 0, int limit = 12}) =>
      _guard(() async {
        final rows = await _db.rpc(
          'get_hall_of_fame',
          params: {'p_offset': offset, 'p_limit': limit},
        );
        return [
          for (final row in rows as List<dynamic>)
            GalleryEntry.fromJson(row as Map<String, dynamic>),
        ];
      });

  @override
  Future<List<GalleryShopItem>> shopItems() => _guard(() async {
    final rows = await _db.rpc('get_contest_shop');
    return [
      for (final row in rows as List<dynamic>)
        GalleryShopItem.fromJson(row as Map<String, dynamic>),
    ];
  });

  @override
  Future<BannerArt> bannerArt(String itemId) => _guard(() async {
    final json = await _db.rpc('get_banner_art', params: {'p_item': itemId});
    return BannerArt.fromJson(json as Map<String, dynamic>);
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw ContestFailure(kindOfMessage(error.message));
    } on sb.AuthException {
      throw const ContestFailure(ContestFailureKind.unknown);
    } catch (error) {
      if (error is ContestFailure) rethrow;
      throw const ContestFailure(ContestFailureKind.network);
    }
  }

  /// The RPCs raise short codes (see the contest migration) as the message.
  static ContestFailureKind kindOfMessage(String message) => switch (message) {
    'not_found' => ContestFailureKind.notFound,
    'not_owner' => ContestFailureKind.notOwner,
    'not_open' => ContestFailureKind.notOpen,
    'not_judging' => ContestFailureKind.notJudging,
    'already_submitted' => ContestFailureKind.alreadySubmitted,
    'contest_full' => ContestFailureKind.contestFull,
    'canvas_too_empty' => ContestFailureKind.canvasTooEmpty,
    'group_too_small' => ContestFailureKind.groupTooSmall,
    'no_canvas' => ContestFailureKind.noCanvas,
    'not_participant' => ContestFailureKind.notParticipant,
    'own_entry' => ContestFailureKind.ownEntry,
    'bad_score' => ContestFailureKind.badScore,
    'empty' => ContestFailureKind.empty,
    'too_long' => ContestFailureKind.tooLong,
    'too_fast' => ContestFailureKind.tooFast,
    'too_many' => ContestFailureKind.tooMany,
    'blocked_word' => ContestFailureKind.blockedWord,
    'too_many_reports' => ContestFailureKind.tooManyReports,
    _ => ContestFailureKind.unknown,
  };
}
