import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_scoring.dart';
import 'package:neo_brutalism_locket/features/search/query_translator.dart';
import 'package:neo_brutalism_locket/features/search/search_backend.dart';
import 'package:neo_brutalism_locket/features/search/search_guard.dart';
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
    this.declined = false,
  }) : strongCount = strongCount ?? posts.length;

  final SearchQuery query;

  /// Best match first (photo searches) or newest first (who / when only).
  final List<RemotePost> posts;

  /// The first [strongCount] of [posts] are clear matches (a sure score that
  /// also beats everyday things the photo could be instead); the rest are only
  /// close to the best photo. It decides the order, not the screen: the scores
  /// of the best photos are often within 0.01 of each other, so the app shows
  /// one list and does not call any of it sure.
  final int strongCount;

  /// The photo part was skipped: the search had to be translated and the
  /// Vietnamese pack is not on the phone yet. [posts] then holds only
  /// caption / place matches.
  final bool needsLanguagePack;

  /// The picture part was skipped on purpose: the search asks what a person
  /// is (see [asksAboutPeople]), which a photo cannot tell. [posts] holds only
  /// caption / place matches.
  final bool declined;
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
  ///
  /// Only a [sure] match can be a clear one. A photo that is merely close to
  /// the best one is shown as "maybe": the closeness rule is about not showing
  /// nothing, and on a search the photos cannot answer (a small library, an
  /// idea instead of a thing) the best photo is a wrong one.
  static const sure = 0.23;
  static const floor = 0.18;
  static const margin = 0.03;
  static const maxResults = 60;

  /// The best photo must score at least [liftGate] above the mean of all
  /// photos for the pictures to be searched at all, in a library of at least
  /// [minLibrary] photos. 0.06 kept 88-95 % of real searches and blocked
  /// 44-70 % of names / nonsense (0.08: 74-87 % kept, 74-90 % blocked); the
  /// lower one is the safer. Not measured on real photos yet: debug builds
  /// print each search's lift (SEARCHDBG) to tune it.
  static const liftGate = 0.06;
  static const minLibrary = 8;

  /// How many of the typed words are looked for in captions and places.
  static const maxWords = 4;

  /// Little words that would match nearly any caption.
  static const _fillerWords = {
    'cua', 'voi', 'cho', 'tai', 'khi', 'nhung', 'cac', 'mot', 'trong', //
    'the', 'and', 'with', 'for', 'are', 'was', 'that', 'this', 'from', 'photo',
  };

  /// Searches of up to this many words get CLIP's "a photo of ..." wording,
  /// which raised their scores by 0.02-0.05.
  ///
  /// Averaging three wordings ("a close-up photo of ...") was tried on
  /// Flickr1k, 30 short searches: mAP 0.553 -> 0.548, no gain, so one wording.
  static const shortWords = 4;

  /// A clear match must also beat the daily quest's 316 everyday labels
  /// ("a chair", "a person", ...) with this share of the probability, like
  /// the quest check. Measured on COCO, one right photo in a library of
  /// 20 / 60: a wrong photo among the clear matches 7 / 18 % of the time
  /// (16 / 35 % with the closeness rule alone). Labels this close to the
  /// search itself (its synonyms) are left out of the contest.
  ///
  /// It was 0.3, which pushed right photos of a scene down to "maybe": the
  /// people and cups in a cafe photo beat "cafe" (shares 0.12-0.22 on the
  /// owner's phone). On Flickr1k (object and scene searches, library of 22)
  /// 0.1 and no share rule at all gave the same precision (97 / 91 %), so
  /// this only keeps out a photo that is clearly something else.
  ///
  /// A "hub" penalty used to lower the score of photos close to many everyday
  /// labels; it was never measured, added nothing on Flickr1k and demoted the
  /// right cafe photos, so it is gone.
  static const clearShare = 0.1;
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
  /// [pinFriend]: the person tapped "with `friend`?" on a name in the text.
  /// [myNames]: what I am called (display name, username): a search that is
  /// only a name is not looked up in the photos.
  Future<SearchOutcome> search(
    String typed, {
    required List<SearchFriend> friends,
    required bool vietnamese,
    String? pinFriend,
    List<String> myNames = const [],
  }) async {
    final query = parseSearchQuery(
      typed,
      friends: friends,
      now: _clock(),
      pinFriend: pinFriend,
    );
    if (query.content.isEmpty) {
      return SearchOutcome(query: query, posts: await _byFilters(query));
    }

    final byText = await _safe(
      () => backend.textMatches(query.content),
      const <RemotePost>[],
    );
    // Posts that name one of the words in the caption or place. Not a
    // requirement (many posts have neither), only more to show and a reason
    // to put a post higher.
    final words = _significantWords(query.content);
    final seen = {for (final p in byText) p.id};
    final byWords = <RemotePost>[];
    for (final word in words) {
      final found = await _safe(
        () => backend.textMatches(word),
        const <RemotePost>[],
      );
      for (final p in found) {
        if (seen.add(p.id)) byWords.add(p);
      }
    }
    // Only what the authors wrote: no photo is matched.
    Future<SearchOutcome> byWordsOnly({
      bool needsLanguagePack = false,
      bool declined = false,
    }) async {
      final shown = await _arrange(
        [...byText, ...byWords],
        query,
        {for (final p in byText) p.id},
        words,
      );
      return SearchOutcome(
        query: query,
        posts: shown.posts,
        strongCount: shown.strong,
        needsLanguagePack: needsLanguagePack,
        declined: declined,
      );
    }

    if (asksAboutPeople(query.content)) return byWordsOnly(declined: true);
    // A name is not something a photo shows: the photo model has no picture
    // for "Thinh", so it hands back whoever looks most like the name's
    // stereotype (measured: names score as high as real searches, so no
    // score cut-off tells them apart).
    if (_onlyNames(query.content, friends, myNames)) return byWordsOnly();
    // English typed in an English app needs no translation, so no pack.
    final needsEnglish =
        vietnamese || foldAccents(query.content) != query.content.toLowerCase();
    if (needsEnglish && !await languagePackReady()) {
      return byWordsOnly(needsLanguagePack: true);
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
    // The translation can turn a word the guard did not know into one it does.
    if (asksAboutPeople(english)) return byWordsOnly(declined: true);
    final wordCount = english.trim().split(RegExp(r'\s+')).length;
    final prompt = wordCount <= shortWords
        ? 'a photo of ${english.trim().replaceAll(RegExp(r'[.!?]+$'), '')}.'
        : english;
    final vector = await _encode(prompt);

    final all = <(String, double)>[
      for (final entry in index.vectors.entries)
        (entry.key, _dot(vector, entry.value)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final best = all.isEmpty ? 0.0 : all.first.$2;
    // A search no photo stands out for: names and nonsense score high on
    // every photo (the best photo's own score cannot tell them from a real
    // search; how far it is above the mean can). Flickr1k, 20 real and 22
    // name / nonsense searches: AUC 0.55 by the best score, 0.89 by this.
    // Skipped in a small library, where the mean says little.
    if (all.length >= minLibrary) {
      final mean = all.fold(0.0, (sum, s) => sum + s.$2) / all.length;
      if (kDebugMode) {
        debugPrint(
          'SEARCHDBG "$typed" lift ${(best - mean).toStringAsFixed(3)} '
          '(gate $liftGate, ${all.length} photos)',
        );
      }
      if (best - mean < liftGate) return byWordsOnly();
    }
    final scored = [
      for (final s in all)
        if (s.$2 >= sure || (s.$2 >= floor && s.$2 >= best - margin)) s,
    ];
    if (kDebugMode) {
      debugPrint(
        'SEARCHDBG "$typed" content "${query.content}" -> "$prompt"; best '
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
    final keep = bank == null ? null : _contestants(vector, bank);
    // Clear: a sure match that also beats the everyday labels. Close to the
    // best photo is enough to be shown, not to be clear. [scored] is best
    // first.
    final clear = <String>{};
    for (final s in scored) {
      if (s.$2 >= sure &&
          (bank == null || _share(s.$1, s.$2, bank, keep!) >= clearShare)) {
        clear.add(s.$1);
      }
    }
    if (kDebugMode) {
      debugPrint('SEARCHDBG clear ${clear.length} of ${scored.length}');
      // Why a photo is clear or only "maybe": its cosine with the search and
      // its share against the everyday labels.
      debugPrint(
        'SEARCHDBG top ${[
          for (final s in scored.take(8))
            '${s.$1.substring(0, 4)} ${s.$2.toStringAsFixed(3)} '
                'share ${bank == null ? '-' : _share(s.$1, s.$2, bank, keep!).toStringAsFixed(2)}'
                '${clear.contains(s.$1) ? ' CLEAR' : ''}',
        ]}',
      );
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
      ...byWords,
      for (final id in ranked)
        if (posts[id] != null && !seen.contains(id)) posts[id]!,
    ];
    final shown = await _arrange(ordered, query, {
      ...clear,
      for (final p in byText) p.id,
    }, words);
    // Debug builds only, and never sent anywhere (the app tells people what
    // they type stays on the phone): a search that found nothing is a word
    // for the glossary in search_query.dart.
    if (kDebugMode && shown.posts.isEmpty) {
      debugPrint('SEARCHMISS "$typed" -> "$prompt"');
    }
    return SearchOutcome(
      query: query,
      posts: shown.posts,
      strongCount: shown.strong,
    );
  }

  /// [content] is nothing but (up to 3) words of a friend's or my own name.
  /// A friend who is called like an ordinary word ("Hoa") makes that word a
  /// name search too: the "with Hoa?" chip is offered instead of pictures.
  bool _onlyNames(
    String content,
    List<SearchFriend> friends,
    List<String> myNames,
  ) {
    List<String> words(String text) => [
      for (final w in foldAccents(text).split(RegExp(r'[^a-z0-9]+')))
        if (w.isNotEmpty) w,
    ];
    final names = {
      for (final name in [for (final f in friends) f.name, ...myNames])
        for (final w in words(name))
          if (w.length >= 2) w,
    };
    final typed = words(content);
    return typed.isNotEmpty && typed.length <= 3 && typed.every(names.contains);
  }

  /// The words of [content] worth looking for in a caption or place: at most
  /// [maxWords], as typed, without the little words everyone uses.
  List<String> _significantWords(String content) {
    final words = <String>[];
    for (final raw in content.split(RegExp(r'\s+'))) {
      final word = raw.replaceAll(RegExp(r'^\W+|\W+$'), '');
      if (word.length < 3 || _fillerWords.contains(foldAccents(word))) continue;
      if (!words.any((w) => w.toLowerCase() == word.toLowerCase())) {
        words.add(word);
      }
    }
    return words.take(maxWords).toList();
  }

  /// Which bank labels compete with the search: all but its synonyms.
  List<bool> _contestants(Float32List query, QuestLabels bank) => [
    for (var j = 0; j < bank.labels.length; j++)
      _dotAt(query, bank.vectors, j * bank.dimension, bank.dimension) <=
          synonym,
  ];

  /// The photo's cosine with every bank label (kept: they never change).
  Float32List _scoresWithBank(String id, QuestLabels bank) {
    final photo = index.vectors[id]!;
    return _bankScores[id] ??= Float32List.fromList([
      for (var j = 0; j < bank.labels.length; j++)
        _dotAt(photo, bank.vectors, j * bank.dimension, bank.dimension),
    ]);
  }

  /// Probability that the photo shows the search rather than any competing
  /// bank label (softmax with CLIP's logit scale).
  double _share(String id, double score, QuestLabels bank, List<bool> keep) {
    final scores = _scoresWithBank(id, bank);
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
  /// Puts [candidates] (best first) in the order they are shown: when and
  /// "mine" are rules, who is not. A post that is clearly a match ([strong])
  /// and has the friend in it (author, tagged, or sent to them) comes first;
  /// the rest follow as "maybe", so a photo of Lan that was posted without a
  /// tag or to other people is still found. Inside each part a caption or
  /// place that names the search words moves a post up.
  Future<({List<RemotePost> posts, int strong})> _arrange(
    List<RemotePost> candidates,
    SearchQuery query,
    Set<String> strong,
    List<String> words,
  ) async {
    final inRange = [
      for (final p in candidates)
        if ((query.from == null || !p.createdAt.isBefore(query.from!)) &&
            (query.until == null || p.createdAt.isBefore(query.until!)) &&
            query.hourMatches(_hourOf(p)) &&
            (!query.mine || p.authorId == myId))
          p,
    ];
    final friend = query.friendId;
    final related = friend == null ? null : await _relatedTo(friend, inRange);
    final top = <RemotePost>[];
    final rest = <RemotePost>[];
    for (final p in inRange) {
      final isTop =
          strong.contains(p.id) && (related == null || related.contains(p.id));
      (isTop ? top : rest).add(p);
    }
    final folded = [for (final w in words) foldAccents(w)];
    return (
      posts: [
        ..._byWordHits(top, folded),
        ..._byWordHits(rest, folded),
      ].take(maxResults).toList(),
      strong: math.min(top.length, maxResults),
    );
  }

  /// Ids among [posts] that are "with" [friend]: they wrote it, they are
  /// tagged on it (they need not be in the picture: a shared meal is "with
  /// Lan" too), or I sent it to them. A database without tags just has
  /// none tagged.
  Future<Set<String>> _relatedTo(String friend, List<RemotePost> posts) async {
    final sent = await backend.sentTo(friend, [
      for (final p in posts)
        if (p.authorId == myId) p.id,
    ]);
    final tagged = await _safe(
      () => backend.taggedWith(friend, [for (final p in posts) p.id]),
      const <String>{},
    );
    return {
      for (final p in posts)
        if (p.authorId == friend) p.id,
      ...sent,
      ...tagged,
    };
  }

  /// [posts] with the ones whose caption or place holds more of [folded]
  /// (accent-folded words) first; equal ones keep their order.
  List<RemotePost> _byWordHits(List<RemotePost> posts, List<String> folded) {
    if (folded.isEmpty) return posts;
    int hits(RemotePost p) {
      final text = foldAccents('${p.caption} ${p.overlay?['place'] ?? ''}');
      return folded.where(text.contains).length;
    }

    final scored = [for (final (i, p) in posts.indexed) (i, hits(p), p)]
      ..sort(
        (a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1),
      );
    return [for (final s in scored) s.$3];
  }

  Future<List<RemotePost>> _byFilters(SearchQuery query) async {
    final friend = query.friendId;
    final List<RemotePost> posts;
    if (friend != null) {
      final all = [
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
        // Photos taken of them and posted by someone else (or by me, to
        // other people).
        ...await _safe(
          () => backend.postsTaggedWith(
            friend,
            from: query.from,
            until: query.until,
          ),
          const <RemotePost>[],
        ),
      ];
      posts = [
        ...{for (final p in all) p.id: p}.values,
      ];
    } else {
      posts = await backend.byAuthor(
        authorId: query.mine ? myId : null,
        from: query.from,
        until: query.until,
      );
    }
    posts.removeWhere((p) => !query.hourMatches(_hourOf(p)));
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  /// The hour a post was taken: the time the poster chose to show on it
  /// ("14:05", when they turned it on: it is the shot, even if the post
  /// waited offline), else when it reached the server.
  static int _hourOf(RemotePost post) {
    final shown = post.overlay?['time'];
    if (shown is String) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(shown.trim());
      final hour = m == null ? null : int.parse(m.group(1)!);
      if (hour != null && hour < 24) return hour;
    }
    return post.createdAt.hour;
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
