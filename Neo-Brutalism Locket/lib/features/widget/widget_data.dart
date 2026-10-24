import 'package:neo_brutalism_locket/features/posts/post_models.dart';

/// The widget that shows every friend's newest photo.
const allSource = 'all';

/// A widget can follow one friend (`u_<id>`) or one group (`g_<id>`) instead
/// of everybody. The key names the source in the widget's stored data.
String friendSource(String userId) => 'u_$userId';
String groupSource(String groupId) => 'g_$groupId';

/// One thing a widget can be set to show, as the picker lists it.
class WidgetChoice {
  const WidgetChoice({required this.key, required this.label});

  /// [friendSource] or [groupSource].
  final String key;
  final String label;
}

/// A group, for the widgets that follow one: who is in it.
class WidgetGroup {
  const WidgetGroup({
    required this.id,
    required this.name,
    required this.memberIds,
  });

  final String id;
  final String name;
  final Set<String> memberIds;
}

/// What the home-screen widget shows: the newest photo a friend sent.
class WidgetPost {
  const WidgetPost({
    required this.postId,
    required this.name,
    required this.caption,
    required this.createdAtMs,
    required this.imageUrl,
    this.authorId,
  });

  final String postId;

  /// Who posted it (a push from an older server does not say).
  final String? authorId;
  final String name;
  final String caption;

  /// Milliseconds since 1970 (the widget turns it into "5m", "2h"...).
  final int createdAtMs;

  /// A short-lived link to download the picture from.
  final String imageUrl;
}

/// Reads the silent message the `notify` function sends when a friend posts.
/// Null when it is not a widget update or has no usable picture link.
WidgetPost? parseWidgetData(Map<String, dynamic>? data) {
  if (data == null || data['type'] != 'widget_update') return null;
  String text(Object? value) => value is String ? value : '';
  final postId = text(data['post_id']);
  final url = Uri.tryParse(text(data['image_url']));
  if (postId.isEmpty || url == null || !url.isScheme('https')) return null;
  return WidgetPost(
    postId: postId,
    name: text(data['name']).trim(),
    caption: text(data['caption']),
    createdAtMs: int.tryParse(text(data['created_at'])) ?? 0,
    imageUrl: url.toString(),
    authorId: text(data['author_id']).isEmpty ? null : text(data['author_id']),
  );
}

/// The newest post from a friend (not from me) that has a picture to show.
/// [posts] is newest first.
RemotePost? latestFriendPost(
  List<RemotePost> posts, {
  required String myId,
  required Set<String> friendIds,
}) {
  for (final post in posts) {
    if (post.authorId == myId || !friendIds.contains(post.authorId)) continue;
    if (post.thumbPath == null && post.isVideo) continue; // nothing to show
    return post;
  }
  return null;
}

/// The newest post that belongs on a widget set to [source]: any friend's
/// ([allSource]), one friend's, or one group member's. Null when there is none.
RemotePost? latestPostForSource(
  List<RemotePost> posts,
  String source, {
  required String myId,
  required Set<String> friendIds,
  Map<String, Set<String>> groups = const {},
}) {
  if (source == allSource) {
    return latestFriendPost(posts, myId: myId, friendIds: friendIds);
  }
  final id = source.length > 2 ? source.substring(2) : '';
  final Set<String> wanted;
  if (source.startsWith('u_')) {
    wanted = {id};
  } else if (source.startsWith('g_')) {
    wanted = groups[id] ?? const {};
  } else {
    return null;
  }
  return latestFriendPost(
    posts,
    myId: myId,
    friendIds: wanted.intersection(friendIds),
  );
}

/// `neolocket://post/<id>` — what tapping the widget opens.
const postLinkHost = 'post';

String postLinkFor(String postId) => 'neolocket://$postLinkHost/$postId';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// The post id in a widget link, or null when [uri] is something else.
String? postIdFromLink(Uri uri) {
  if (uri.scheme != 'neolocket' || uri.host != postLinkHost) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 1 || !_uuid.hasMatch(segments.single)) return null;
  return segments.single.toLowerCase();
}
