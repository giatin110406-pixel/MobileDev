import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

/// The entries of one contest, loaded a page at a time in the order the server
/// accepted them (so a person who scrolls far gets the next page on demand).
class GalleryStore extends ChangeNotifier {
  GalleryStore(this.repository, {this.contestId, this.pageSize = 20});

  final ContestRepository repository;

  /// Null = this week's contest.
  final String? contestId;
  final int pageSize;

  final List<GalleryEntry> _entries = [];
  int? _nextAfter = 0;
  ContestPhase _phase = ContestPhase.upcoming;
  String? _resolvedContestId;
  bool _loading = false;
  bool _loaded = false;
  ContestFailure? _error;

  /// In the order the server accepted them (seq 1 first).
  List<GalleryEntry> get entries => List.unmodifiable(_entries);
  ContestPhase get phase => _phase;
  String? get resolvedContestId => _resolvedContestId ?? contestId;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  bool get hasMore => _nextAfter != null;
  ContestFailure? get error => _error;

  Future<void> load() async {
    _entries.clear();
    _nextAfter = 0;
    _loaded = false;
    await loadMore();
  }

  Future<void> loadMore() async {
    final after = _nextAfter;
    if (_loading || after == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.gallery(
        contestId: contestId,
        after: after,
        limit: pageSize,
      );
      for (final entry in page.entries) {
        if (_entries.every((known) => known.id != entry.id)) {
          _entries.add(entry);
        }
      }
      _entries.sort((a, b) => a.seq.compareTo(b.seq));
      _nextAfter = page.nextAfter;
      _phase = page.phase;
      _resolvedContestId = page.contestId;
      _loaded = true;
    } on ContestFailure catch (failure) {
      _error = failure;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// After rating or reacting on the detail screen, so the list agrees.
  void replace(GalleryEntry entry) {
    final index = _entries.indexWhere((known) => known.id == entry.id);
    if (index < 0) return;
    _entries[index] = entry;
    notifyListeners();
  }
}
