import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';

/// The posts shown in the feed. Reloads itself when a friend sends something.
class PostsStore extends ChangeNotifier {
  PostsStore(this.repository) {
    _subscription = repository.incoming.listen((_) => refresh());
  }

  final PostsRepository repository;
  StreamSubscription<void>? _subscription;
  List<RemotePost> _posts = const [];
  bool _loaded = false;
  bool _loading = false;
  bool _again = false;
  bool _loadingMore = false;
  bool _failed = false;
  bool _hasMore = true;

  /// Posts per page, for the feed and the history.
  static const pageSize = 50;

  /// Newest first.
  List<RemotePost> get posts => _posts;
  bool get isLoaded => _loaded;

  /// There may be older posts to load with [loadMore].
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  /// The last refresh could not reach the server (the old posts stay).
  bool get failed => _failed;

  Future<void> refresh() async {
    // Asked again while loading (say a new message arrived): load once more
    // when this load ends, so the newest data is not missed.
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    _again = false;
    try {
      _posts = await repository.loadFeed(limit: pageSize);
      _hasMore = _posts.length >= pageSize;
      _loaded = true;
      _failed = false;
    } on PostsFailure {
      _failed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
    if (_again) await refresh();
  }

  /// Adds the next page of older posts (history scrolling).
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _posts.isEmpty) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final older = await repository.loadFeed(
        before: _posts.last.createdAt,
        limit: pageSize,
      );
      final known = {for (final post in _posts) post.id};
      _posts = [
        ..._posts,
        for (final post in older)
          if (!known.contains(post.id)) post,
      ];
      _hasMore = older.length >= pageSize;
      _failed = false;
    } on PostsFailure {
      _failed = true;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    repository.dispose();
    super.dispose();
  }
}
