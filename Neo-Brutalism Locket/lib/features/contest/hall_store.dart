import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

/// Every painting that ever won, newest week first (and first place first within a
/// week), loaded a page at a time.
class HallStore extends ChangeNotifier {
  HallStore(this.repository, {this.pageSize = 12});

  final ContestRepository repository;
  final int pageSize;

  final List<GalleryEntry> _entries = [];
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  ContestFailure? _error;

  List<GalleryEntry> get entries => List.unmodifiable(_entries);
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  ContestFailure? get error => _error;

  Future<void> load() async {
    _entries.clear();
    _hasMore = true;
    _loaded = false;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.hallOfFame(
        offset: _entries.length,
        limit: pageSize,
      );
      for (final entry in page) {
        if (_entries.every((known) => known.id != entry.id)) {
          _entries.add(entry);
        }
      }
      _hasMore = page.length >= pageSize;
      _loaded = true;
    } on ContestFailure catch (failure) {
      _error = failure;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
