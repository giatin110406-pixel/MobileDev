import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A group's album for one event: the photos its members took from
/// [startsAt] up to (not including) [endsAt].
class Album {
  const Album({
    required this.id,
    required this.groupId,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.createdBy,
    this.itemCount = 0,
  });

  final String id;
  final String groupId;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;
  final String? createdBy;
  final int itemCount;

  /// Photos taken now belong in it.
  bool isOpenAt(DateTime time) =>
      !time.isBefore(startsAt) && time.isBefore(endsAt);

  static const columns =
      'id, group_id, name, starts_at, ends_at, created_by, created_at, '
      'album_items(count)';

  factory Album.fromRow(Map<String, dynamic> row) {
    final counts = row['album_items'];
    final count = counts is List && counts.isNotEmpty
        ? (counts.first as Map)['count'] as int? ?? 0
        : 0;
    return Album(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(row['ends_at'] as String).toLocal(),
      createdBy: row['created_by'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      itemCount: count,
    );
  }
}

/// A photo (or clip) in an album, with the post's file paths.
class AlbumItem {
  const AlbumItem({
    required this.albumId,
    required this.postId,
    required this.authorId,
    required this.mediaPath,
    required this.createdAt,
    this.kind = 'photo',
    this.thumbPath,
    this.originalPath,
    this.caption = '',
  });

  final String albumId;
  final String postId;
  final String authorId;
  final String kind;
  final String mediaPath;
  final String? thumbPath;

  /// The shot before its style, when the author sent it.
  final String? originalPath;
  final String caption;

  /// When the post was made.
  final DateTime createdAt;

  bool get isVideo => kind == 'video';

  static const columns =
      'album_id, post_id, author_id, kind, media_path, thumb_path, '
      'original_path, caption, post_created_at';

  factory AlbumItem.fromRow(Map<String, dynamic> row) => AlbumItem(
    albumId: row['album_id'] as String,
    postId: row['post_id'] as String,
    authorId: row['author_id'] as String,
    kind: (row['kind'] as String?) ?? 'photo',
    mediaPath: row['media_path'] as String,
    thumbPath: row['thumb_path'] as String?,
    originalPath: row['original_path'] as String?,
    caption: (row['caption'] as String?) ?? '',
    createdAt: DateTime.parse(row['post_created_at'] as String).toLocal(),
  );
}

enum AlbumFailureKind {
  notMember,
  notFound,
  notAllowed,
  badName,
  badWindow,
  albumLimit,
  network,
  unknown,
}

class AlbumFailure implements Exception {
  const AlbumFailure(this.kind);

  final AlbumFailureKind kind;

  @override
  String toString() => 'AlbumFailure($kind)';
}

abstract interface class AlbumsRepository {
  /// The albums of all my groups, newest event first.
  Future<List<Album>> loadAlbums();

  /// Oldest first.
  Future<List<AlbumItem>> loadItems(String albumId);

  /// Returns the new album's id.
  Future<String> create({
    required String groupId,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<void> delete(String albumId);

  /// Puts one of my posts in the album. False when it may not go in (made
  /// outside the window, album gone); throws [AlbumFailure] on no connection.
  Future<bool> add(String albumId, String postId);

  Future<void> remove(String albumId, String postId);

  /// My posts from [from] to [to], newest first (to pick older ones to add).
  Future<List<RemotePost>> myPostsBetween(DateTime from, DateTime to);
}

class SupabaseAlbumsRepository implements AlbumsRepository {
  SupabaseAlbumsRepository({required this.myId});

  final String myId;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<List<Album>> loadAlbums() => _guard(() async {
    final rows = await _db
        .from('group_albums')
        .select(Album.columns)
        .order('starts_at', ascending: false);
    return [for (final row in rows) Album.fromRow(row)];
  });

  @override
  Future<List<AlbumItem>> loadItems(String albumId) => _guard(() async {
    final rows = await _db
        .from('album_items')
        .select(AlbumItem.columns)
        .eq('album_id', albumId)
        .order('post_created_at');
    return [for (final row in rows) AlbumItem.fromRow(row)];
  });

  @override
  Future<String> create({
    required String groupId,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  }) => _guard(() async {
    final id = await _db.rpc(
      'create_album',
      params: {
        'p_group': groupId,
        'p_name': name,
        'p_starts': startsAt.toUtc().toIso8601String(),
        'p_ends': endsAt.toUtc().toIso8601String(),
      },
    );
    return id as String;
  });

  @override
  Future<void> delete(String albumId) =>
      _guard(() => _db.rpc('delete_album', params: {'p_album': albumId}));

  @override
  Future<bool> add(String albumId, String postId) => _guard(() async {
    final added = await _db.rpc(
      'add_to_album',
      params: {'p_album': albumId, 'p_post': postId},
    );
    return added == true;
  });

  @override
  Future<void> remove(String albumId, String postId) => _guard(
    () => _db.rpc(
      'remove_from_album',
      params: {'p_album': albumId, 'p_post': postId},
    ),
  );

  @override
  Future<List<RemotePost>> myPostsBetween(DateTime from, DateTime to) =>
      _guard(() async {
        final rows = await _db
            .from('posts')
            .select(RemotePost.columns)
            .eq('author_id', myId)
            .filter('deleted_at', 'is', null)
            .gte('created_at', from.toUtc().toIso8601String())
            .lt('created_at', to.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(300);
        return [for (final row in rows) RemotePost.fromRow(row)];
      });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error, stack) {
      // The person only sees "something went wrong"; the log keeps the cause.
      AppLog.warn('albums', error.message, stack);
      throw AlbumFailure(kindOfMessage(error.message));
    } on sb.AuthException {
      throw const AlbumFailure(AlbumFailureKind.unknown);
    } catch (error, stack) {
      if (error is AlbumFailure) rethrow;
      AppLog.warn('albums', error, stack);
      throw const AlbumFailure(AlbumFailureKind.network);
    }
  }

  /// The RPCs raise short codes (see the albums migration) as the message.
  static AlbumFailureKind kindOfMessage(String message) => switch (message) {
    'not_member' => AlbumFailureKind.notMember,
    'not_found' => AlbumFailureKind.notFound,
    'not_allowed' => AlbumFailureKind.notAllowed,
    'bad_name' => AlbumFailureKind.badName,
    'bad_window' => AlbumFailureKind.badWindow,
    'album_limit' => AlbumFailureKind.albumLimit,
    _ => AlbumFailureKind.unknown,
  };
}
