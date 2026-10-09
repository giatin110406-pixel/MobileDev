import 'package:neo_brutalism_locket/features/posts/post_models.dart';

/// Whose posts the history shows.
sealed class HistoryFilter {
  const HistoryFilter();

  /// Everything sent to me and everything I sent.
  static const all = HistoryAll();

  /// Only what I sent.
  static const mine = HistoryMine();

  /// Only what one friend sent me.
  static HistoryFrom from(String friendId) => HistoryFrom(friendId);
}

class HistoryAll extends HistoryFilter {
  const HistoryAll();
}

class HistoryMine extends HistoryFilter {
  const HistoryMine();
}

class HistoryFrom extends HistoryFilter {
  const HistoryFrom(this.friendId);

  final String friendId;

  @override
  bool operator ==(Object other) =>
      other is HistoryFrom && other.friendId == friendId;

  @override
  int get hashCode => friendId.hashCode;
}

/// The posts that pass [filter], in the same (newest first) order.
List<RemotePost> filterHistory(
  List<RemotePost> posts, {
  required String myId,
  required HistoryFilter filter,
}) => [
  for (final post in posts)
    if (switch (filter) {
      HistoryAll() => true,
      HistoryMine() => post.authorId == myId,
      HistoryFrom(:final friendId) => post.authorId == friendId,
    })
      post,
];

/// One month of posts, for a section header.
class HistoryMonth {
  const HistoryMonth(this.month, this.posts);

  /// The first day of the month.
  final DateTime month;
  final List<RemotePost> posts;
}

/// Splits newest-first [posts] into months (newest month first), by the
/// phone's local time.
List<HistoryMonth> groupByMonth(List<RemotePost> posts) {
  final groups = <HistoryMonth>[];
  for (final post in posts) {
    final local = post.createdAt.toLocal();
    final first = DateTime(local.year, local.month);
    if (groups.isEmpty || groups.last.month != first) {
      groups.add(HistoryMonth(first, []));
    }
    groups.last.posts.add(post);
  }
  return groups;
}
