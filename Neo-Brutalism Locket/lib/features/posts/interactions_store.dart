import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';

/// Reactions and "seen by" for the posts in the feed.
class InteractionsStore extends ChangeNotifier {
  InteractionsStore(this.repository, {required this.myId}) {
    _subscription = repository.reactionsChanged.listen((_) => _reload());
  }

  final InteractionsRepository repository;
  final String myId;
  StreamSubscription<void>? _subscription;
  Map<String, PostActivity> _activity = const {};
  Map<String, String> _mine = const {};
  List<RemotePost> _posts = const [];
  final _viewed = <String>{};

  /// What happened to my posts, by post id.
  Map<String, PostActivity> get activity => _activity;

  /// My reaction to a post I received, if any.
  String? myReaction(String postId) => _mine[postId];

  /// Loads activity for the posts in [posts] (mine) and my reactions to the
  /// others.
  Future<void> load(List<RemotePost> posts) async {
    _posts = posts;
    await _reload();
  }

  Future<void> _reload() async {
    final mine = [
      for (final p in _posts)
        if (p.authorId == myId) p.id,
    ];
    final others = [
      for (final p in _posts)
        if (p.authorId != myId) p.id,
    ];
    try {
      final results = await Future.wait([
        repository.loadActivity(mine),
        repository.loadMyReactions(others),
      ]);
      _activity = results[0] as Map<String, PostActivity>;
      _mine = results[1] as Map<String, String>;
      notifyListeners();
    } on InteractionFailure {
      // Keep what is shown; the next load tries again.
    }
  }

  /// Reacts with [emoji] (null removes it). The emoji shows at once; if the
  /// server refuses, it is undone and the failure is rethrown.
  Future<void> react(String postId, String? emoji) async {
    final before = _mine;
    _mine = {..._mine};
    if (emoji == null) {
      _mine.remove(postId);
    } else {
      _mine[postId] = emoji;
    }
    notifyListeners();
    try {
      await repository.react(postId, emoji);
    } on InteractionFailure {
      _mine = before;
      notifyListeners();
      rethrow;
    }
  }

  /// Tells the author once per post per run.
  Future<void> markViewed(String postId) async {
    if (!_viewed.add(postId)) return;
    try {
      await repository.markViewed(postId);
    } on InteractionFailure {
      _viewed.remove(postId); // try again next time it is on screen
    }
  }

  Future<void> deletePost(RemotePost post) async {
    await repository.deletePost(
      post.id,
      filePaths: [post.mediaPath, ?post.thumbPath],
    );
    _activity = {..._activity}..remove(post.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    repository.dispose();
    super.dispose();
  }
}
