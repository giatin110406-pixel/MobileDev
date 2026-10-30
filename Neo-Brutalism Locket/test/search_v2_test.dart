import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/search/photo_search.dart';
import 'package:neo_brutalism_locket/features/search/search_index.dart';
import 'package:neo_brutalism_locket/features/search/search_query.dart';
import 'package:neo_brutalism_locket/features/search/search_v2_client.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';

import 'photo_search_test.dart' show FakeBackend, post, uuid;

class UnorderedBackend extends FakeBackend {
  UnorderedBackend(super.posts, super.vectors);
  @override
  Future<List<RemotePost>> postsByIds(List<String> ids) async =>
      (await super.postsByIds(ids)).reversed.toList();
}

void main() {
  const config = StylizeServerConfig(
    address: 'http://localhost:8766',
    token: 'app-token',
  );
  HttpSearchV2 remote({
    bool unavailable = false,
    List<String> ids = const [],
    List<http.Request>? requests,
  }) => HttpSearchV2(
    accessToken: () => 'user-jwt',
    loadConfig: () async => config,
    client: MockClient((request) async {
      requests?.add(request);
      expect(request.headers['Authorization'], 'Bearer user-jwt');
      expect(request.headers['X-Locket-Token'], 'app-token');
      if (unavailable) return http.Response('unavailable', 503);
      if (request.url.path.endsWith('/parse')) {
        final rules = (jsonDecode(request.body) as Map)['rules'] as Map;
        return http.Response(
          jsonEncode({
            'query': {
              ...rules,
              'terms': ['dog'],
            },
            'declined': false,
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'post_ids': ids, 'pending': 2}), 200);
    }),
  );

  test(
    'parser output goes to search with caller JWT and rule filters',
    () async {
      final requests = <http.Request>[];
      final client = remote(ids: [uuid(1)], requests: requests);
      final rules = SearchQuery(
        content: 'chó',
        mine: true,
        from: DateTime.utc(2026, 10, 1),
        until: DateTime.utc(2026, 11),
      );
      final result = await client.search(
        'chó của tôi tháng 10',
        rules,
        friends: [],
        myNames: [],
        now: DateTime.utc(2026, 10, 29),
      );
      expect(result.ids, [uuid(1)]);
      expect(result.pending, 2);
      expect(requests.map((r) => r.url.path), ['/search/parse', '/search']);
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['mine'], true);
      expect(body['terms'], ['dog']);
      expect(body['from_time'], '2026-10-01T00:00:00.000Z');
      client.close();
    },
  );

  test(
    'v2 empty answer is final and does not run v1 or caption matching',
    () async {
      final backend = FakeBackend({uuid(1): post(1, caption: 'dog')}, {});
      final search = PhotoSearch(
        myId: 'me',
        backend: backend,
        v2: remote(),
        encodeText: (_) async => throw StateError('v1 must not run'),
      );
      final result = await search.search('dog', friends: [], vietnamese: false);
      expect(result.posts, isEmpty);
      expect(result.usedV2, true);
      expect(result.quickResults, false);
      await search.close();
    },
  );

  test('unavailable server uses labelled v1 fallback', () async {
    final dir = Directory.systemTemp.createTempSync('v2_fallback');
    addTearDown(() => dir.deleteSync(recursive: true));
    final backend = FakeBackend({uuid(1): post(1, caption: 'dog')}, {});
    final search = PhotoSearch(
      myId: 'me',
      backend: backend,
      v2: remote(unavailable: true),
      index: SearchIndex(
        userId: 'me',
        source: backend,
        folder: () async => dir,
      ),
      encodeText: (_) async => throw StateError('no vector needed'),
    );
    // A lift-free empty index still encodes; use a zero vector for that path.
    final safe = PhotoSearch(
      myId: 'me',
      backend: backend,
      v2: remote(unavailable: true),
      index: search.index,
      encodeText: (_) async => Float32List(512),
      loadBank: () async => throw StateError('no bank'),
    );
    final result = await safe.search('dog', friends: [], vietnamese: false);
    expect(result.posts.map((p) => p.id), [uuid(1)]);
    expect(result.quickResults, true);
    expect(result.usedV2, false);
    await safe.close();
    await search.close();
  });

  test(
    'v2 preserves server ranking when Supabase rows arrive unordered',
    () async {
      final backend = UnorderedBackend({
        uuid(1): post(1),
        uuid(2): post(2),
      }, {});
      final search = PhotoSearch(
        myId: 'me',
        backend: backend,
        v2: remote(ids: [uuid(2), uuid(1)]),
      );
      final result = await search.search('dog', friends: [], vietnamese: false);
      expect(result.posts.map((p) => p.id), [uuid(2), uuid(1)]);
      await search.close();
    },
  );
}
