import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_scoring.dart';
import 'package:neo_brutalism_locket/features/search/photo_embedding.dart';
import 'package:neo_brutalism_locket/features/search/photo_search.dart';
import 'package:neo_brutalism_locket/features/search/search_backend.dart';
import 'package:neo_brutalism_locket/features/search/search_index.dart';

/// A unit vector along axis [axis] (and a bit of [mix] along axis 1).
Float32List axisVector(int axis, {double mix = 0}) {
  final v = Float32List(embeddingDimension)..[axis] = 1;
  if (mix > 0) {
    v[axis] = 1 - mix;
    v[1] = mix;
  }
  return v;
}

String b64(Float32List v) => base64Encode(float16Bytes(v));

String uuid(int n) =>
    '00000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';

class FakeBackend implements SearchBackend {
  FakeBackend(this.posts, this.vectors);

  final Map<String, RemotePost> posts;
  final Map<String, Float32List> vectors;
  final sentToFriend = <String, Set<String>>{};
  final tagged = <String, Set<String>>{};
  int pages = 0;

  @override
  Future<List<EmbeddingRow>> page({
    DateTime? after,
    String? afterId,
    required int limit,
  }) async {
    pages++;
    final rows = [
      for (final (i, e) in vectors.entries.indexed)
        (
          id: e.key,
          embeddedAt: DateTime.utc(2026, 1, 1, 0, i),
          embedding: b64(e.value),
        ),
    ];
    return rows
        .where((r) => after == null || r.embeddedAt.isAfter(after))
        .take(limit)
        .toList();
  }

  @override
  Future<Set<String>> visibleIds() async => vectors.keys.toSet();

  @override
  Future<List<RemotePost>> postsByIds(List<String> ids) async => [
    for (final id in ids)
      if (posts[id] != null) posts[id]!,
  ];

  @override
  Future<Set<String>> sentTo(String friendId, List<String> postIds) async =>
      (sentToFriend[friendId] ?? {}).intersection(postIds.toSet());

  @override
  Future<Set<String>> taggedWith(String friendId, List<String> postIds) async =>
      (tagged[friendId] ?? {}).intersection(postIds.toSet());

  @override
  Future<List<RemotePost>> postsTaggedWith(
    String friendId, {
    DateTime? from,
    DateTime? until,
    int limit = 120,
  }) async => [
    for (final id in tagged[friendId] ?? <String>{})
      if (posts[id] != null &&
          (from == null || !posts[id]!.createdAt.isBefore(from)) &&
          (until == null || posts[id]!.createdAt.isBefore(until)))
        posts[id]!,
  ];

  @override
  Future<List<RemotePost>> textMatches(String text, {int limit = 30}) async => [
    for (final p in posts.values)
      if ('${p.caption} ${p.overlay?['place'] ?? ''}'.toLowerCase().contains(
        text.toLowerCase(),
      ))
        p,
  ];

  @override
  Future<List<RemotePost>> byAuthor({
    String? authorId,
    DateTime? from,
    DateTime? until,
    int limit = 120,
  }) async => [
    for (final p in posts.values)
      if ((authorId == null || p.authorId == authorId) &&
          (from == null || !p.createdAt.isBefore(from)) &&
          (until == null || p.createdAt.isBefore(until)))
        p,
  ];

  @override
  Future<List<RemotePost>> mineSentTo(
    String friendId, {
    DateTime? from,
    DateTime? until,
    int limit = 120,
  }) async => [
    for (final id in sentToFriend[friendId] ?? <String>{})
      if (posts[id] != null) posts[id]!,
  ];
}

RemotePost post(
  int n, {
  String author = 'me',
  DateTime? at,
  String caption = '',
  String? place,
  String? time, // the time the poster chose to show on the post, "14:05"
}) => RemotePost(
  id: uuid(n),
  authorId: author,
  mediaPath: '$author/$n.jpg',
  createdAt: at ?? DateTime(2026, 10, n),
  caption: caption,
  overlay: place == null && time == null
      ? null
      : {'place': ?place, 'time': ?time},
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('search'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('index on the phone', () {
    test(
      'syncs, keeps a copy, and forgets posts I can no longer see',
      () async {
        final backend = FakeBackend({}, {
          uuid(1): axisVector(0),
          uuid(2): axisVector(2),
        });
        final index = SearchIndex(
          userId: 'me',
          source: backend,
          folder: () async => dir,
        );
        expect(await index.sync(), 2);
        expect(index.vectors[uuid(2)]![2], 1);

        backend.vectors.remove(uuid(1)); // deleted post
        await index.sync();
        expect(index.vectors.keys, [uuid(2)]);

        final reopened = SearchIndex(
          userId: 'me',
          source: backend,
          folder: () async => dir,
        );
        await reopened.load();
        expect(reopened.vectors.keys, [uuid(2)]);
        expect(await reopened.sync(), 0, reason: 'only what is new is fetched');
      },
    );
  });

  group('search', () {
    PhotoSearch engine(FakeBackend backend, {bool ready = true}) => PhotoSearch(
      myId: 'me',
      backend: backend,
      index: SearchIndex(
        userId: 'me',
        source: backend,
        folder: () async => dir,
      ),
      clock: () => DateTime(2026, 10, 22),
      // "dog" points along axis 0, anything else along axis 3
      encodeText: ready
          ? (english) async => axisVector(english.contains('dog') ? 0 : 3)
          : null,
    );

    test('best match first; weak matches are left out', () async {
      final backend = FakeBackend(
        {
          for (final n in [1, 2, 3]) uuid(n): post(n),
        },
        {
          uuid(1): axisVector(0, mix: 0.5), // a bit like a dog
          uuid(2): axisVector(0), // a dog
          uuid(3): axisVector(5), // something else
        },
      );
      final out = await engine(
        backend,
      ).search('a dog', friends: const [], vietnamese: false);
      expect([for (final p in out.posts) p.id], [uuid(2), uuid(1)]);
      expect(out.needsLanguagePack, isFalse);
    });

    test('a short search shows the best photos even below the sure score, '
        'and is worded "a photo of ..."', () async {
      // cosines with the query (axis 0): 0.20, 0.18, 0.12
      Float32List at(double cos) {
        final v = Float32List(embeddingDimension)
          ..[0] = cos
          ..[9] = 1;
        return v;
      }

      final backend = FakeBackend(
        {
          for (final n in [1, 2, 3]) uuid(n): post(n),
        },
        {uuid(1): at(0.20), uuid(2): at(0.18), uuid(3): at(0.12)},
      );
      final prompts = <String>[];
      final search = PhotoSearch(
        myId: 'me',
        backend: backend,
        index: SearchIndex(
          userId: 'me',
          source: backend,
          folder: () async => dir,
        ),
        encodeText: (english) async {
          prompts.add(english);
          return axisVector(0);
        },
      );
      final out = await search.search(
        'phone',
        friends: const [],
        vietnamese: false,
      );
      expect(
        prompts.single,
        'a photo of phone.',
      ); // 0.20 is the best and above the floor; 0.18 is within 0.03 of it;
      // 0.12 is neither
      expect([for (final p in out.posts) p.id], [uuid(1), uuid(2)]);

      await search.search(
        'a man in a red shirt next to a motorbike',
        friends: const [],
        vietnamese: false,
      );
      expect(prompts.last, 'a man in a red shirt next to a motorbike');
    });

    test(
      'a search that is only a name is not looked up in the photos',
      () async {
        final backend = FakeBackend(
          {uuid(1): post(1)},
          {uuid(1): axisVector(0)},
        );
        var encoded = 0;
        final search = PhotoSearch(
          myId: 'me',
          backend: backend,
          index: SearchIndex(
            userId: 'me',
            source: backend,
            folder: () async => dir,
          ),
          encodeText: (_) async {
            encoded++;
            return axisVector(0);
          },
        );
        // my own name, with or without accents, in any order of its words
        var out = await search.search(
          'thinh',
          friends: const [],
          vietnamese: false,
          myNames: const ['Nguyễn Thịnh'],
        );
        expect(encoded, 0);
        expect(out.posts, isEmpty);
        // a friend's first name
        out = await search.search(
          'Lan',
          friends: const [(id: 'f1', name: 'Lan Anh')],
          vietnamese: false,
        );
        expect(encoded, 0);
        // a name next to something to look for is still a picture search
        out = await search.search(
          'dog Lan',
          friends: const [(id: 'f1', name: 'Lan Anh')],
          vietnamese: false,
        );
        expect(encoded, 1);
        // a word that is nobody's name is searched as before
        await search.search(
          'thinh',
          friends: const [(id: 'f1', name: 'Lan Anh')],
          vietnamese: false,
        );
        expect(encoded, 2);
      },
    );

    test('a search no photo stands out for shows no pictures', () async {
      Float32List at(double cos) => Float32List(embeddingDimension)
        ..[0] = cos
        ..[9] = 1;
      var engines = 0;
      PhotoSearch engineFor(Map<String, Float32List> vectors, int count) {
        final backend = FakeBackend({
          for (var n = 1; n <= count; n++) uuid(n): post(n),
        }, vectors);
        // a user of its own: the index keeps its vectors in a file per user
        final user = 'gate${engines++}';
        return PhotoSearch(
          myId: user,
          backend: backend,
          index: SearchIndex(
            userId: user,
            source: backend,
            folder: () async => dir,
          ),
          encodeText: (_) async => axisVector(0),
        );
      }

      // ten photos that all score 0.20: the best is no better than the rest
      final flat = await engineFor({
        for (var n = 1; n <= 10; n++) uuid(n): at(0.20),
      }, 10).search('thinh', friends: const [], vietnamese: false);
      expect(flat.posts, isEmpty);

      // the same search with one photo well above the rest
      final standout = await engineFor({
        for (var n = 1; n <= 10; n++) uuid(n): at(n == 1 ? 0.30 : 0.10),
      }, 10).search('dog', friends: const [], vietnamese: false);
      expect([for (final p in standout.posts) p.id], [uuid(1)]);

      // fewer than 8 photos: the mean says little, so the rule is skipped
      final small = await engineFor({
        for (var n = 1; n <= 5; n++) uuid(n): at(0.20),
      }, 5).search('thinh', friends: const [], vietnamese: false);
      expect(small.posts, isNotEmpty);
    });

    test('a part of the day filters on the hour the photo was taken: the time '
        'shown on the post, else when it was posted', () async {
      DateTime at(int hour) => DateTime(2026, 10, 20, hour);
      final backend = FakeBackend(
        {
          uuid(1): post(1, at: at(15)), // posted in the afternoon
          uuid(2): post(2, at: at(9)), // posted in the morning
          // shot at 14:30, posted that evening: the shown time wins
          uuid(3): post(3, at: at(20), time: '14:30'),
          // posted at 15:00 but shot at 09:10
          uuid(4): post(4, at: at(15), time: '09:10'),
        },
        {for (var n = 1; n <= 4; n++) uuid(n): axisVector(0)},
      );
      final search = PhotoSearch(
        myId: 'me',
        backend: backend,
        index: SearchIndex(
          userId: 'me',
          source: backend,
          folder: () async => dir,
        ),
        encodeText: (_) async => axisVector(0),
      );
      // only a time of day: no photo model needed
      final byHour = await search.search(
        'lúc chiều',
        friends: const [],
        vietnamese: false,
      );
      expect({for (final p in byHour.posts) p.id}, {uuid(1), uuid(3)});
      expect(byHour.query.fromHour, 12);

      // with something to look for, the same hours apply to what it finds
      final withPicture = await search.search(
        'dog in the afternoon',
        friends: const [],
        vietnamese: false,
      );
      expect({for (final p in withPicture.posts) p.id}, {uuid(1), uuid(3)});
    });

    test('a photo posted after the last search is found right away', () async {
      final backend = FakeBackend({uuid(1): post(1)}, {uuid(1): axisVector(0)});
      final search = engine(backend);
      expect(
        (await search.search(
          'dog',
          friends: const [],
          vietnamese: false,
        )).posts.length,
        1,
      );
      backend.posts[uuid(2)] = post(2);
      backend.vectors[uuid(2)] = axisVector(0);
      final out = await search.search(
        'dog',
        friends: const [],
        vietnamese: false,
      );
      expect({for (final p in out.posts) p.id}, {uuid(1), uuid(2)});
    });

    test('a photo close in score but more like an everyday thing goes to '
        '"maybe"', () async {
      Float32List photo(Map<int, double> axes) {
        final v = Float32List(embeddingDimension);
        axes.forEach((i, x) => v[i] = x);
        return v;
      }

      final backend = FakeBackend(
        {uuid(1): post(1), uuid(2): post(2)},
        {
          uuid(1): photo({0: 0.30, 5: 0.9}), // the umbrella
          uuid(2): photo({0: 0.28, 9: 0.9}), // close score, but a chair
        },
      );
      // the bank: one everyday label, "a chair", along axis 9
      final bank = QuestLabels(
        labels: const ['a chair'],
        vectors: axisVector(9),
        dimension: embeddingDimension,
        logitScale: 64,
        matchScore: 0.5,
        inputSize: 256,
        quests: const {},
      );
      final out = await PhotoSearch(
        myId: 'me',
        backend: backend,
        index: SearchIndex(
          userId: 'me',
          source: backend,
          folder: () async => dir,
        ),
        encodeText: (_) async => axisVector(0),
        loadBank: () async => bank,
      ).search('umbrella', friends: const [], vietnamese: false);
      expect([for (final p in out.posts) p.id], [uuid(1), uuid(2)]);
      expect(out.strongCount, 1);
    });

    test(
      'only a sure match is clear; close to the best photo is "maybe"',
      () async {
        // cosines with the query (axis 0): 0.20, 0.18 (below the sure score)
        Float32List at(double cos) {
          final v = Float32List(embeddingDimension)
            ..[0] = cos
            ..[9] = 1;
          return v;
        }

        final backend = FakeBackend(
          {uuid(1): post(1), uuid(2): post(2)},
          {uuid(1): at(0.20), uuid(2): at(0.18)},
        );
        final out = await PhotoSearch(
          myId: 'me',
          backend: backend,
          index: SearchIndex(
            userId: 'me',
            source: backend,
            folder: () async => dir,
          ),
          encodeText: (_) async => axisVector(0),
        ).search('phone', friends: const [], vietnamese: false);
        expect([for (final p in out.posts) p.id], [uuid(1), uuid(2)]);
        expect(out.strongCount, 0, reason: 'shown, but not clear');
      },
    );

    test('a photo that is clearly an everyday thing instead is only "maybe"; '
        'one that merely has everyday things in it is still clear', () async {
      Float32List photo(Map<int, double> axes) {
        final v = Float32List(embeddingDimension);
        axes.forEach((i, x) => v[i] = x);
        return v;
      }

      final backend = FakeBackend(
        {uuid(1): post(1), uuid(2): post(2), uuid(3): post(3)},
        {
          uuid(1): photo({0: 0.30, 5: 0.9}), // the umbrella
          // the same score for the search, but a chair is a better answer
          uuid(2): photo({0: 0.30, 9: 0.34}),
          // close to many everyday things, none of them closer than the search
          uuid(3): photo({0: 0.30, 9: 0.29, 10: 0.29, 11: 0.29}),
        },
      );
      final bank = QuestLabels(
        labels: const ['a chair', 'a table', 'a person'],
        vectors: Float32List.fromList([
          ...axisVector(9),
          ...axisVector(10),
          ...axisVector(11),
        ]),
        dimension: embeddingDimension,
        logitScale: 64,
        matchScore: 0.5,
        inputSize: 256,
        quests: const {},
      );
      final out = await PhotoSearch(
        myId: 'me',
        backend: backend,
        index: SearchIndex(
          userId: 'me',
          source: backend,
          folder: () async => dir,
        ),
        encodeText: (_) async => axisVector(0),
        loadBank: () async => bank,
      ).search('umbrella', friends: const [], vietnamese: false);
      expect(
        {for (final p in out.posts.take(out.strongCount)) p.id},
        {uuid(1), uuid(3)},
      );
      expect(out.posts.last.id, uuid(2), reason: 'the chair photo is "maybe"');
    });

    test(
      'a search about what a person is does not look at the photos',
      () async {
        final backend = FakeBackend(
          {uuid(1): post(1), uuid(2): post(2, caption: 'gay pride parade')},
          {uuid(1): axisVector(0)},
        );
        final search = PhotoSearch(
          myId: 'me',
          backend: backend,
          index: SearchIndex(
            userId: 'me',
            source: backend,
            folder: () async => dir,
          ),
          encodeText: (_) async =>
              throw StateError('the photos must not be searched'),
        );
        final out = await search.search(
          'gay',
          friends: const [],
          vietnamese: false,
        );
        expect(out.declined, isTrue);
        expect(
          [for (final p in out.posts) p.id],
          [uuid(2)],
          reason: 'what the author wrote can still be found',
        );

        final vi = await search.search(
          'đồng tính',
          friends: const [],
          vietnamese: true,
        );
        expect(vi.declined, isTrue);
        expect(vi.posts, isEmpty);
      },
    );

    test('a caption match comes first, even with no vector', () async {
      final backend = FakeBackend(
        {uuid(1): post(1), uuid(9): post(9, caption: 'my dog Bin')},
        {uuid(1): axisVector(0)},
      );
      final out = await engine(
        backend,
      ).search('dog', friends: const [], vietnamese: false);
      expect([for (final p in out.posts) p.id], [uuid(9), uuid(1)]);
    });

    test(
      'when is a rule; who only decides what is clear and what is maybe',
      () async {
        final backend = FakeBackend(
          {
            uuid(1): post(1, author: 'lan'),
            uuid(2): post(2, author: 'minh'),
            uuid(3): post(3), // mine, sent to Lan
            uuid(4): post(4), // mine, not sent to Lan, not tagged
            uuid(5): post(5, author: 'lan', at: DateTime(2024, 5)),
          },
          {
            for (final n in [1, 2, 3, 4, 5]) uuid(n): axisVector(0),
          },
        )..sentToFriend['lan'] = {uuid(3)};
        final out = await engine(backend).search(
          'dog với Lan tháng này',
          friends: const [(id: 'lan', name: 'Lan')],
          vietnamese: false,
        );
        expect(out.strongCount, 2);
        expect({for (final p in out.posts.take(2)) p.id}, {uuid(1), uuid(3)});
        expect(
          {for (final p in out.posts) p.id},
          {uuid(1), uuid(2), uuid(3), uuid(4)},
          reason: 'the others stay, after; 2024 is out of range',
        );
      },
    );

    test('a tag puts a photo with the friend first, sent or not', () async {
      final backend = FakeBackend(
        {
          uuid(1): post(1), // mine, tagged Lan, sent to nobody
          uuid(2): post(2), // mine, nothing says Lan is in it
          uuid(3): post(3, author: 'minh'), // Minh's, tagged Lan
        },
        {
          for (final n in [1, 2, 3]) uuid(n): axisVector(0),
        },
      )..tagged['lan'] = {uuid(1), uuid(3)};
      final out = await engine(backend).search(
        'dog với Lan',
        friends: const [(id: 'lan', name: 'Lan')],
        vietnamese: false,
      );
      expect(out.strongCount, 2);
      expect({for (final p in out.posts.take(2)) p.id}, {uuid(1), uuid(3)});
      expect(out.posts.last.id, uuid(2), reason: 'untagged is not dropped');
    });

    test('a name without "with" is offered; pinning applies it', () async {
      final backend = FakeBackend(
        {uuid(1): post(1), uuid(2): post(2)},
        {uuid(1): axisVector(0), uuid(2): axisVector(0)},
      )..tagged['lan'] = {uuid(1)};
      const friends = [(id: 'lan', name: 'Lan')];
      final search = engine(backend);

      final offered = await search.search(
        'Lan dog',
        friends: friends,
        vietnamese: false,
      );
      expect(offered.query.friendId, isNull);
      expect(offered.query.friendHints.single.id, 'lan');
      expect(offered.strongCount, 2, reason: 'nothing was filtered');

      final pinned = await search.search(
        'Lan dog',
        friends: friends,
        vietnamese: false,
        pinFriend: 'lan',
      );
      expect(pinned.query.friendId, 'lan');
      expect(pinned.strongCount, 1);
      expect(pinned.posts.first.id, uuid(1));
    });

    test('a place that names a word helps, and is never required', () async {
      final backend = FakeBackend(
        {
          uuid(1): post(1), // no place at all
          uuid(2): post(2, place: 'Vung Tau'),
          uuid(3): post(3, place: 'Da Lat'),
        },
        {
          for (final n in [1, 2, 3]) uuid(n): axisVector(0),
        },
      );
      final out = await engine(
        backend,
      ).search('dog Vung', friends: const [], vietnamese: false);
      expect(out.posts.first.id, uuid(2), reason: 'its place names the word');
      expect(
        {for (final p in out.posts) p.id},
        {uuid(1), uuid(2), uuid(3)},
        reason: 'photos without a place are still found by the picture',
      );
    });

    test('a caption or place can find a post that has no vector', () async {
      final backend = FakeBackend(
        {uuid(1): post(1), uuid(2): post(2, place: 'Vung Tau')},
        {uuid(1): axisVector(0)},
      );
      final out = await engine(
        backend,
      ).search('dog Vung', friends: const [], vietnamese: false);
      expect([for (final p in out.posts) p.id], [uuid(1), uuid(2)]);
      expect(out.strongCount, 1, reason: 'the one by words alone is "maybe"');
    });

    test('only who / when also lists photos tagged with the friend', () async {
      final backend = FakeBackend({
        uuid(1): post(1, author: 'lan'),
        uuid(3): post(3, author: 'minh'), // Minh's photo, Lan is in it
        uuid(2): post(2, author: 'minh'),
      }, {})..tagged['lan'] = {uuid(3)};
      final out = await engine(backend, ready: false).search(
        'ảnh với Lan',
        friends: const [(id: 'lan', name: 'Lan')],
        vietnamese: true,
      );
      expect([for (final p in out.posts) p.id], [uuid(3), uuid(1)]);
    });

    test('only who / when: newest first, no model needed', () async {
      final backend = FakeBackend({
        uuid(1): post(1, author: 'lan'),
        uuid(7): post(7, author: 'lan'),
        uuid(2): post(2),
      }, {});
      final out = await engine(backend, ready: false).search(
        'ảnh với Lan',
        friends: const [(id: 'lan', name: 'Lan')],
        vietnamese: true,
      );
      expect([for (final p in out.posts) p.id], [uuid(7), uuid(1)]);
      expect(out.needsLanguagePack, isFalse);
    });
  });
}
