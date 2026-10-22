import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/search/search_index.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// What photo search asks the server, besides the vectors.
abstract interface class SearchBackend implements EmbeddingSource {
  Future<List<RemotePost>> postsByIds(List<String> ids);

  /// Which of my [postIds] went to [friendId].
  Future<Set<String>> sentTo(String friendId, List<String> postIds);

  /// Posts whose caption or place contains [text] (as typed).
  Future<List<RemotePost>> textMatches(String text, {int limit});

  /// Posts by me or by [authorId], newest first, in a date range (for a
  /// search that is only "who / when").
  Future<List<RemotePost>> byAuthor({
    String? authorId,
    DateTime? from,
    DateTime? until,
    int limit,
  });

  /// My posts that went to [friendId], newest first, in a date range.
  Future<List<RemotePost>> mineSentTo(
    String friendId, {
    DateTime? from,
    DateTime? until,
    int limit,
  });
}

class SupabaseSearchBackend implements SearchBackend {
  SupabaseSearchBackend({required this.myId});

  final String myId;
  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<List<EmbeddingRow>> page({
    DateTime? after,
    String? afterId,
    required int limit,
  }) async {
    final rows =
        await _db.rpc(
              'post_embeddings',
              params: {
                'p_after': after?.toUtc().toIso8601String(),
                'p_after_id': afterId,
                'p_limit': limit,
              },
            )
            as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          id: r['id'] as String,
          embeddedAt: DateTime.parse(r['embedded_at'] as String),
          embedding: r['embedding'] as String,
        ),
    ];
  }

  @override
  Future<Set<String>> visibleIds() async =>
      ((await _db.rpc('visible_embedding_ids')) as List<dynamic>)
          .cast<String>()
          .toSet();

  @override
  Future<List<RemotePost>> postsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _db
        .from('posts')
        .select(RemotePost.columns)
        .inFilter('id', ids);
    return [for (final r in rows) RemotePost.fromRow(r)];
  }

  @override
  Future<Set<String>> sentTo(String friendId, List<String> postIds) async {
    if (postIds.isEmpty) return const {};
    final rows = await _db
        .from('post_recipients')
        .select('post_id')
        .eq('user_id', friendId)
        .inFilter('post_id', postIds);
    return {for (final r in rows) r['post_id'] as String};
  }

  @override
  Future<List<RemotePost>> textMatches(String text, {int limit = 30}) async {
    // PostgREST "or" syntax: commas and brackets would end the pattern.
    final safe = text.replaceAll(RegExp(r'[,()*%\\]'), ' ').trim();
    if (safe.length < 2) return const [];
    final rows = await _db
        .from('posts')
        .select(RemotePost.columns)
        .or('caption.ilike.*$safe*,overlay->>place.ilike.*$safe*')
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) RemotePost.fromRow(r)];
  }

  @override
  Future<List<RemotePost>> byAuthor({
    String? authorId,
    DateTime? from,
    DateTime? until,
    int limit = 120,
  }) async {
    var query = _db.from('posts').select(RemotePost.columns);
    if (authorId != null) query = query.eq('author_id', authorId);
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (until != null) {
      query = query.lt('created_at', until.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final r in rows) RemotePost.fromRow(r)];
  }

  @override
  Future<List<RemotePost>> mineSentTo(
    String friendId, {
    DateTime? from,
    DateTime? until,
    int limit = 120,
  }) async {
    final ids = await _db
        .from('post_recipients')
        .select('post_id')
        .eq('user_id', friendId)
        .limit(1000);
    final mine = [for (final r in ids) r['post_id'] as String];
    if (mine.isEmpty) return const [];
    var query = _db
        .from('posts')
        .select(RemotePost.columns)
        .eq('author_id', myId)
        .inFilter('id', mine);
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (until != null) {
      query = query.lt('created_at', until.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final r in rows) RemotePost.fromRow(r)];
  }
}
