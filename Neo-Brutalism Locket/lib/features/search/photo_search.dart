import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_scoring.dart';
import 'package:neo_brutalism_locket/features/search/query_translator.dart';
import 'package:neo_brutalism_locket/features/search/search_backend.dart';
import 'package:neo_brutalism_locket/features/search/search_index.dart';
import 'package:neo_brutalism_locket/features/search/search_query.dart';
import 'package:neo_brutalism_locket/features/search/search_text_encoder.dart';

/// What one search found.
class SearchOutcome {
  const SearchOutcome({
    required this.query,
    required this.posts,
    int? strongCount,
    this.needsLanguagePack = false,
  }) : strongCount = strongCount ?? posts.length;

  final SearchQuery query;

  /// Best match first (photo searches) or newest first (who / when only).
  final List<RemotePost> posts;

  /// The first [strongCount] of [posts] are clear matches; the rest are
  /// "maybe": close to the best photo, but they do not beat everyday things
  /// the photo could be instead.
  final int strongCount;

  /// The photo part was skipped: the search had to be translated and the
  /// Vietnamese pack is not on the phone yet. [posts] then holds only
  /// caption / place matches.
  final bool needsLanguagePack;
}

/// Photo search over the posts I may see (archive-ai-search-plan.md, C3):
/// who / when -> filters; the rest -> English (ML Kit, on the phone) -> text
/// vector -> compared with every post vector in [SearchIndex].
class PhotoSearch {
  PhotoSearch({
    required this.myId,
    required this.backend,
    SearchIndex? index,
    QueryTranslator? translator,
    Future<Float32List> Function(String english)? encodeText,
    Future<QuestLabels> Function()? loadBank,
    DateTime Function()? clock,
  }) : index = index ?? SearchIndex(userId: myId, source: backend),
       _translator = translator,
       _encodeOverride = encodeText,
       _loadBank = loadBank ?? QuestLabels.load,
       _clock = clock ?? DateTime.now;

  final String myId;
  final SearchBackend backend;
  final SearchIndex index;
  QueryTranslator? _translator;
  final Future<Float32List> Function(String english)? _encodeOverride;
  final Future<QuestLabels> Function() _loadBank;
  final DateTime Function() _clock;

  /// Which photos are shown. A fixed cut-off failed short searches ("điện
  /// thoại" scores below 0.22 even on the right photo); measured on COCO
  /// libraries of 20 / 60 / 300 photos (plan C, short queries): a sure match
  /// at [sure], or a photo close to the best one ([margin]) above [floor].
  /// Nothing was shown 17 / 7 / 0.6 % of the time instead of 43 / 31 / 11 %.
  static const sure = 0.23;
  static const floor = 0.18;
  static const margin = 0.03;
  static const maxResults = 60;

  /// Searches of up to this many words get CLIP's "a photo of ..." wording,
  /// which raised their scores by 0.02-0.05.
  static const shortWords = 4;

  /// A clear match must also beat the daily quest's 316 everyday labels
  /// ("a chair", "a person", ...) with this share of the probability, like
  /// the quest check. Measured on COCO, one right photo in a library of
  /// 20 / 60: a wrong photo among the clear matches 7 / 18 % of the time
  /// (16 / 35 % with the closeness rule alone). Labels this close to the
  /// search itself (its synonyms) are left out of the contest.
  static const clearShare = 0.3;
  static const synonym = 0.80;

  SearchTextEncoder? _encoder;
  DateTime? _prunedAt;
  Future<QuestLabels?>? _bank;

  /// Each photo's cosines with the bank labels (they never change).
  final Map<String, Float32List> _bankScores = {};

  QueryTranslator get translator => _translator ??= QueryTranslator();

  /// The Vietnamese pack is on the phone (the model itself ships in the app).
  /// Anything that cannot be checked counts as missing.
  Future<bool> languagePackReady() async {
    if (_encodeOverride != null) return true;
    try {
      return await translator.isReady;
    } catch (e, st) {
      AppLog.warn('photo_search', e, st);
      return false;
    }
  }

  /// Fetches the Vietnamese pack (about 30 MB, ML Kit cannot ship it in the
  /// app). [wifiOnly]: wait for Wi-Fi, for the quiet download at start.
  Future<void> prepareLanguagePack({bool wifiOnly = false}) async {
    if (!await translator.prepare(wifiOnly: wifiOnly)) {
      throw StateError('language pack download failed');
    }
  }

  /// [vietnamese]: the app is in Vietnamese, so text without accents is
  /// still translated.
  Future<SearchOutcome> search(
    String typed, {
    required List<SearchFriend> friends,
    required bool vietnamese,
  }) async {
    final query = parseSearchQuery(typed, friends: friends, now: _clock());
    if (query.content.isEmpty) {
      return SearchOutcome(query: query, posts: await _byFilters(query));
    }

    final byText = await _safe(
      () => backend.textMatches(query.content),
      const <RemotePost>[],
    );
    // English typed in an English app needs no translation, so no pack.
    final needsEnglish =
        vietnamese || foldAccents(query.content) != query.content.toLowerCase();
    if (needsEnglish && !await languagePackReady()) {
      return SearchOutcome(
        query: query,
        posts: await _filter(byText, query),
        needsLanguagePack: true,
      );
    }

    // New vectors on every search, so a photo posted a moment ago is found;
    // forgetting deleted posts lists every id, so only every 5 minutes.
    // Offline (or slow): the copy on the phone is used as it is.
    final now = DateTime.now();
    final prune =
        _prunedAt == null ||
        now.difference(_prunedAt!) > const Duration(minutes: 5);
    await index.load();
    final synced = await _safe(
      () => index
          .sync(prune: prune)
          .timeout(Duration(seconds: prune ? 10 : 3))
          .then((_) => true),
      false,
    );
    if (synced && prune) _prunedAt = now;
    final english = needsEnglish
        ? await translator.toEnglish(query.content)
        : query.content;
    final words = english.trim().split(RegExp(r'\s+')).length;
    final prompt = words <= shortWords
        ? 'a photo of ${english.trim().replaceAll(RegExp(r'[.!?]+$'), '')}.'
        : english;
    final vector = await _encode(prompt);

    final all = <(String, double)>[
      for (final entry in index.vectors.entries)
        (entry.key, _dot(vector, entry.value)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final best = all.isEmpty ? 0.0 : all.first.$2;
    final scored = [
      for (final s in all)
        if (s.$2 >= sure || (s.$2 >= floor && s.$2 >= best - margin)) s,
    ];
    if (kDebugMode) {
      debugPrint(
        'SEARCHDBG "$typed" -> "$prompt"; best '
        '${[for (final s in all.take(5)) s.$2.toStringAsFixed(3)]}, '
        'shown ${scored.length} of ${all.length}',
      );
    }
    final bank = await (_bank ??= _loadBank().then<QuestLabels?>(
      (b) => b,
      onError: (Object e) {
        AppLog.warn('photo_search', e);
        return null; // no bank: every shown photo counts as clear
      },
    ));
    final clear = <String>{};
    final keep = bank == null ? null : _contestants(vector, bank);
    for (final s in scored) {
      if (bank == null ||
          (s.$2 >= math.max(floor, best - margin) &&
              _share(s.$1, s.$2, bank, keep!) >= clearShare)) {
        clear.add(s.$1);
      }
    }
    if (kDebugMode) {
      debugPrint('SEARCHDBG clear ${clear.length} of ${scored.length}');
    }
    final ranked = [
      for (final s in scored.take(maxResults * 2))
        if (clear.contains(s.$1)) s.$1,
      for (final s in scored.take(maxResults * 2))
        if (!clear.contains(s.$1)) s.$1,
    ];
    final posts = {for (final p in await backend.postsByIds(ranked)) p.id: p};

    final ordered = <RemotePost>[
      ...byText,
      for (final id in ranked)
        if (posts[id] != null && !byText.any((p) => p.id == id)) posts[id]!,
    ];
    final filtered = (await _filter(ordered, query)).take(maxResults).toList();
    final strong = {...clear, for (final p in byText) p.id};
    return SearchOutcome(
      query: query,
      posts: filtered,
      strongCount: filtered.takeWhile((p) => strong.contains(p.id)).length,
    );
  }

  /// Which bank labels compete with the search: all but its synonyms.
  List<bool> _contestants(Float32List query, QuestLabels bank) => [
    for (var j = 0; j < bank.labels.length; j++)
      _dotAt(query, bank.vectors, j * bank.dimension, bank.dimension) <=
          synonym,
  ];

  /// Probability that the photo shows the search rather than any competing
  /// bank label (softmax with CLIP's logit scale).
  double _share(String id, double score, QuestLabels bank, List<bool> keep) {
    final photo = index.vectors[id]!;
    final scores = _bankScores[id] ??= Float32List.fromList([
      for (var j = 0; j < bank.labels.length; j++)
        _dotAt(photo, bank.vectors, j * bank.dimension, bank.dimension),
    ]);
    final scale = bank.logitScale;
    var top = score;
    for (var j = 0; j < scores.length; j++) {
      if (keep[j] && scores[j] > top) top = scores[j];
    }
    final mine = math.exp((score - top) * scale);
    var total = mine;
    for (var j = 0; j < scores.length; j++) {
      if (keep[j]) total += math.exp((scores[j] - top) * scale);
    }
    return mine / total;
  }

  Future<Float32List> _encode(String english) {
    final override = _encodeOverride;
    if (override != null) return override(english);
    return (_encoder ??= SearchTextEncoder()).encode(english);
  }

  /// Keeps the posts that pass the who / when filters, in their order.
  Future<List<RemotePost>> _filter(
    List<RemotePost> posts,
    SearchQuery query,
  ) async {
    final friend = query.friendId;
    final sent = friend == null
        ? const <String>{}
        : await backend.sentTo(friend, [
            for (final p in posts)
              if (p.authorId == myId) p.id,
          ]);
    return [
      for (final p in posts)
        if ((query.from == null || !p.createdAt.isBefore(query.from!)) &&
            (query.until == null || p.createdAt.isBefore(query.until!)) &&
            (!query.mine || p.authorId == myId) &&
            (friend == null ||
                p.authorId == friend ||
                (p.authorId == myId && sent.contains(p.id))))
          p,
    ];
  }

  Future<List<RemotePost>> _byFilters(SearchQuery query) async {
    final friend = query.friendId;
    final List<RemotePost> posts;
    if (friend != null) {
      posts = [
        ...await backend.byAuthor(
          authorId: friend,
          from: query.from,
          until: query.until,
        ),
        ...await backend.mineSentTo(
          friend,
          from: query.from,
          until: query.until,
        ),
      ];
    } else {
      posts = await backend.byAuthor(
        authorId: query.mine ? myId : null,
        from: query.from,
        until: query.until,
      );
    }
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<void> close() async => _encoder?.close();
}

double _dotAt(Float32List a, Float32List b, int offset, int length) {
  var dot = 0.0;
  for (var i = 0; i < length; i++) {
    dot += a[i] * b[offset + i];
  }
  return dot;
}

double _dot(Float32List a, Float32List b) {
  var dot = 0.0;
  for (var i = 0; i < math.min(a.length, b.length); i++) {
    dot += a[i] * b[i];
  }
  return dot;
}

Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
  try {
    return await call();
  } catch (e, st) {
    AppLog.warn('photo_search', e, st);
    return fallback;
  }
}
