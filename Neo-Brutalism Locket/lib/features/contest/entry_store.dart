import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

/// One entry on its own screen: my rating, reactions and comments.
class EntryStore extends ChangeNotifier {
  EntryStore(this.repository, GalleryEntry entry) : _entry = entry;

  final ContestRepository repository;
  GalleryEntry _entry;
  EntryDetail? _detail;
  List<EntryComment> _comments = const [];
  bool _loaded = false;
  ContestFailure? _error;
  bool _sending = false;

  GalleryEntry get entry => _detail?.entry ?? _entry;
  EntryDetail? get detail => _detail;
  List<EntryComment> get comments => _comments;
  bool get isLoaded => _loaded;
  ContestFailure? get error => _error;
  bool get sending => _sending;

  ContestPhase get phase => _detail?.phase ?? ContestPhase.judging;

  /// Only people from the entering groups may rate and comment, only while
  /// rating is open, and never on their own group's entry.
  bool get canRate =>
      (_detail?.participant ?? false) &&
      phase == ContestPhase.judging &&
      !entry.mine;

  bool get canComment =>
      (_detail?.participant ?? false) && phase == ContestPhase.judging;

  Map<String, int> get reactions => _detail?.reactions ?? const {};

  Future<void> load() async {
    try {
      final results = await Future.wait([
        repository.entry(_entry.id),
        repository.comments(_entry.id),
      ]);
      _detail = results[0] as EntryDetail;
      _comments = results[1] as List<EntryComment>;
      _loaded = true;
      _error = null;
    } on ContestFailure catch (failure) {
      _error = failure;
    }
    notifyListeners();
  }

  /// Rates the entry 1 to 5. The star shows at once; a refusal puts it back.
  /// Throws [ContestFailure].
  Future<void> rate(int score) async {
    final before = entry;
    _entry = before.copyWith(myScore: score);
    _detail = _detail == null
        ? null
        : EntryDetail(
            entry: _entry,
            phase: _detail!.phase,
            participant: _detail!.participant,
            reactions: _detail!.reactions,
            commentCount: _detail!.commentCount,
          );
    notifyListeners();
    try {
      await repository.vote(before.id, score);
    } on ContestFailure {
      _entry = before;
      if (_detail != null) {
        _detail = EntryDetail(
          entry: before,
          phase: _detail!.phase,
          participant: _detail!.participant,
          reactions: _detail!.reactions,
          commentCount: _detail!.commentCount,
        );
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Sets my reaction, or takes it back when it is the one I already have.
  Future<void> react(String emoji) async {
    final mine = entry.myEmoji;
    final next = mine == emoji ? null : emoji;
    await repository.react(entry.id, next);
    await load();
  }

  /// Throws [ContestFailure].
  Future<void> comment(String body) async {
    final text = body.trim();
    if (text.isEmpty || _sending) return;
    _sending = true;
    notifyListeners();
    try {
      await repository.comment(entry.id, text);
      _comments = await repository.comments(entry.id);
      _detail = _detail == null
          ? null
          : EntryDetail(
              entry: entry,
              phase: _detail!.phase,
              participant: _detail!.participant,
              reactions: _detail!.reactions,
              commentCount: _comments.length,
            );
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> reportEntry(ReportReasonKind reason, {String? details}) =>
      repository.report(entryId: entry.id, reason: reason, details: details);

  Future<void> reportComment(
    EntryComment comment,
    ReportReasonKind reason, {
    String? details,
  }) async {
    await repository.report(
      commentId: comment.id,
      reason: reason,
      details: details,
    );
    _comments = [
      for (final other in _comments)
        if (other.id != comment.id) other,
    ];
    notifyListeners();
  }
}
