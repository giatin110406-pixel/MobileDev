import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/albums/albums_repository.dart';

/// The albums of all my groups, for the group screens and the composer (which
/// offers the albums open right now).
class AlbumsStore extends ChangeNotifier {
  AlbumsStore(this.repository, {DateTime Function() clock = DateTime.now})
    : _clock = clock;

  final AlbumsRepository repository;
  final DateTime Function() _clock;
  List<Album> _albums = const [];
  bool _loaded = false;
  bool _loading = false;
  AlbumFailure? _loadError;

  List<Album> get albums => _albums;
  bool get isLoaded => _loaded;
  bool get isLoading => _loading;

  /// Set when the last refresh failed (the old list stays visible).
  AlbumFailure? get loadError => _loadError;

  /// Newest event first.
  List<Album> forGroup(String groupId) => [
    for (final album in _albums)
      if (album.groupId == groupId) album,
  ];

  /// Albums a photo taken now belongs in.
  List<Album> get open {
    final now = _clock();
    return [
      for (final album in _albums)
        if (album.isOpenAt(now)) album,
    ];
  }

  Album? byId(String id) {
    for (final album in _albums) {
      if (album.id == id) return album;
    }
    return null;
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _albums = await repository.loadAlbums();
      _loaded = true;
      _loadError = null;
    } on AlbumFailure catch (failure) {
      _loadError = failure;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Throws [AlbumFailure]; reloads on success. Returns the new album's id.
  Future<String> create({
    required String groupId,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final id = await repository.create(
      groupId: groupId,
      name: name,
      startsAt: startsAt,
      endsAt: endsAt,
    );
    await refresh();
    return id;
  }

  Future<void> delete(Album album) async {
    await repository.delete(album.id);
    await refresh();
  }

  /// Adds my posts to [album]; returns how many went in. Reloads after.
  Future<int> addPosts(Album album, Iterable<String> postIds) async {
    var added = 0;
    try {
      for (final id in postIds) {
        if (await repository.add(album.id, id)) added++;
      }
    } finally {
      await refresh();
    }
    return added;
  }

  Future<void> remove(AlbumItem item) async {
    await repository.remove(item.albumId, item.postId);
    await refresh();
  }
}
