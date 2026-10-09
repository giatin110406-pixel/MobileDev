import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';

/// The signed-in person's friends and pending requests, for the UI. Every
/// action reloads from the server so the screen never shows a guess.
class FriendsStore extends ChangeNotifier {
  FriendsStore(this.repository);

  final FriendsRepository repository;
  FriendsSnapshot _snapshot = const FriendsSnapshot();
  bool _loaded = false;
  bool _loading = false;
  FriendsFailure? _loadError;

  FriendsSnapshot get snapshot => _snapshot;
  List<Friend> get friends => _snapshot.friends;
  List<FriendRequest> get incoming => _snapshot.incoming;
  List<FriendRequest> get outgoing => _snapshot.outgoing;
  bool get isLoaded => _loaded;
  bool get isLoading => _loading;

  /// Set when the last refresh failed (the old list stays visible).
  FriendsFailure? get loadError => _loadError;

  Friend? friendById(String id) {
    for (final friend in friends) {
      if (friend.person.id == id) return friend;
    }
    return null;
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _snapshot = await repository.load();
      _loaded = true;
      _loadError = null;
    } on FriendsFailure catch (failure) {
      _loadError = failure;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Person>> search(String query) => repository.search(query);

  /// Throws [FriendsFailure]; reloads on success.
  Future<SendResult> sendRequest(String username) async {
    final result = await repository.sendRequest(username);
    await refresh();
    return result;
  }

  Future<void> respond(FriendRequest request, {required bool accept}) async {
    await repository.respond(request.id, accept: accept);
    await refresh();
  }

  Future<void> cancel(FriendRequest request) async {
    await repository.cancel(request.id);
    await refresh();
  }

  Future<void> removeFriend(Person person) async {
    await repository.removeFriend(person.id);
    await refresh();
  }
}
