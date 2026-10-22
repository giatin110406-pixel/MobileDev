import 'dart:typed_data';

import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// One of my posts that has no search vector yet, and the picture to make it
/// from.
class BackfillItem {
  const BackfillItem(this.postId, this.imagePath);

  final String postId;

  /// Path in the `media` bucket.
  final String imagePath;
}

abstract interface class BackfillSource {
  /// My own posts without a vector, newest first.
  Future<List<BackfillItem>> postsWithoutVector({required int limit});
  Future<Uint8List> download(String path);
  Future<void> setVector(String postId, String embedding);
}

/// Gives my posts from before photo search their vectors, a few per app
/// start, so friends can find them too. Only the author can do it: only the
/// author's phone has the right to write the vector
/// (`set_post_embedding`). Friends' old posts get theirs from their own phones.
class EmbeddingBackfill {
  EmbeddingBackfill(this.source, {required this.embed});

  final BackfillSource source;
  final Future<String?> Function(Uint8List photo) embed;
  bool _running = false;

  /// Returns how many posts got a vector. Never throws: a database without
  /// the search columns, no network or a bad picture just ends the run.
  Future<int> run({int limit = 20}) async {
    if (_running) return 0;
    _running = true;
    var done = 0;
    try {
      for (final item in await source.postsWithoutVector(limit: limit)) {
        final vector = await embed(await source.download(item.imagePath));
        if (vector == null) continue;
        await source.setVector(item.postId, vector);
        done++;
      }
    } catch (e, st) {
      AppLog.warn('embedding_backfill', e, st);
    } finally {
      _running = false;
    }
    return done;
  }
}

class SupabaseBackfillSource implements BackfillSource {
  SupabaseBackfillSource({required this.myId});

  final String myId;
  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<List<BackfillItem>> postsWithoutVector({required int limit}) async {
    final rows = await _db
        .from('posts')
        .select('id, media_path, thumb_path, original_path')
        .eq('author_id', myId)
        .isFilter('embedding', null)
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows)
        BackfillItem(
          row['id'] as String,
          // the shot before its style; else the small still (videos too)
          (row['original_path'] ?? row['thumb_path'] ?? row['media_path'])
              as String,
        ),
    ];
  }

  @override
  Future<Uint8List> download(String path) =>
      _db.storage.from('media').download(path);

  @override
  Future<void> setVector(String postId, String embedding) => _db.rpc(
    'set_post_embedding',
    params: {'p_id': postId, 'p_embedding': embedding},
  );
}
