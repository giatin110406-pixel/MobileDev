import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/search/search_query.dart';

class SearchV2ConfigStore extends StylizeServerConfigStore {
  const SearchV2ConfigStore();

  @override
  Future<StylizeServerConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StylizeServerConfig(
      address:
          prefs.getString('search_v2_server_address') ??
          const String.fromEnvironment('SEARCH_V2_URL'),
      token:
          prefs.getString('search_v2_server_token') ??
          const String.fromEnvironment('SEARCH_V2_TOKEN'),
    );
  }

  @override
  Future<void> save(StylizeServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('search_v2_server_address', config.address.trim());
    await prefs.setString('search_v2_server_token', config.token.trim());
  }
}

class V2Unavailable implements Exception {}

class V2SearchResult {
  const V2SearchResult(
    this.query,
    this.ids, {
    this.pending = 0,
    this.declined = false,
  });
  final SearchQuery query;
  final List<String> ids;
  final int pending;
  final bool declined;
}

abstract interface class SearchV2Backend {
  Future<V2SearchResult> search(
    String text,
    SearchQuery rules, {
    required List<SearchFriend> friends,
    required List<String> myNames,
    required DateTime now,
  });
  void close();
}

class HttpSearchV2 implements SearchV2Backend {
  HttpSearchV2({
    required this.accessToken,
    http.Client? client,
    Future<StylizeServerConfig> Function()? loadConfig,
  }) : _client = client ?? http.Client(),
       _loadConfig = loadConfig ?? const SearchV2ConfigStore().load;

  final String? Function() accessToken;
  final http.Client _client;
  final Future<StylizeServerConfig> Function() _loadConfig;

  @override
  Future<V2SearchResult> search(
    String text,
    SearchQuery rules, {
    required List<SearchFriend> friends,
    required List<String> myNames,
    required DateTime now,
  }) async {
    final config = await _loadConfig();
    if (!config.isConfigured) throw V2Unavailable();
    final ruleData = <String, dynamic>{
      'terms': <String>[],
      'friend_id': rules.friendId,
      'mine': rules.mine,
      'from_time': rules.from?.toUtc().toIso8601String(),
      'until_time': rules.until?.toUtc().toIso8601String(),
      'name_only': false,
    };
    final parsed = await _request(config, 'search/parse', {
      'text': text,
      'visual_text': rules.content,
      'now': now.toUtc().toIso8601String(),
      'friends': [
        for (final f in friends) {'id': f.id, 'name': f.name},
      ],
      'my_names': myNames,
      'rules': ruleData,
    });
    final data = Map<String, dynamic>.from(parsed['query'] as Map);
    final proposedFriend = data['friend_id'] as String?;
    final friend =
        rules.friendId ??
        (friends.any((f) => f.id == proposedFriend) ? proposedFriend : null);
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;
    var from = parseDate(data['from_time']);
    var until = parseDate(data['until_time']);
    if (from == null || until == null || !from.isBefore(until)) {
      from = rules.from;
      until = rules.until;
    }
    from = rules.from ?? from;
    until = rules.until ?? until;
    final query = SearchQuery(
      content: rules.content,
      friendId: friend,
      mine: rules.mine || data['mine'] == true,
      from: from,
      until: until,
      fromHour: rules.fromHour,
      untilHour: rules.untilHour,
      friendHints: friend == null ? rules.friendHints : const [],
    );
    if (parsed['declined'] == true) {
      return V2SearchResult(query, const [], declined: true);
    }
    final terms = (data['terms'] as List).cast<String>();
    if (terms.isEmpty || data['name_only'] == true) {
      return V2SearchResult(query, const [], declined: true);
    }
    final result = await _request(config, 'search', {
      'terms': terms,
      'friend_id': query.friendId,
      'mine': query.mine,
      'from_time': query.from?.toUtc().toIso8601String(),
      'until_time': query.until?.toUtc().toIso8601String(),
      'name_only': false,
    });
    return V2SearchResult(
      query,
      (result['post_ids'] as List).cast<String>(),
      pending: result['pending'] as int? ?? 0,
    );
  }

  Future<Map<String, dynamic>> _request(
    StylizeServerConfig config,
    String path,
    Map<String, dynamic> body,
  ) async {
    final jwt = accessToken();
    if (jwt == null || jwt.isEmpty) throw V2Unavailable();
    final base = config.baseUri;
    if (!{'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty) {
      throw V2Unavailable();
    }
    final prefix = base.path.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .post(
          base.replace(path: '$prefix/$path', query: null, fragment: null),
          headers: {
            'Content-Type': 'application/json',
            'X-Locket-Token': config.token,
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: path.endsWith('parse') ? 45 : 90));
    if (response.statusCode != 200) throw V2Unavailable();
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  @override
  void close() => _client.close();
}
