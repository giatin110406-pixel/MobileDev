import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';

/// The player's live state for the UI: the Sunbit badge, quest card, shop and
/// profile all listen to one store, so a reward shows everywhere at once.
class PlayerStore extends ChangeNotifier {
  PlayerStore({PlayerGateway? repository})
    : repository = repository ?? PlayerRepository();

  final PlayerGateway repository;
  PlayerState? _state;
  QuestPost? _lastCompleted;

  /// The quest post made by the latest [completeQuest] (to send to friends).
  QuestPost? get lastCompletedPost => _lastCompleted;

  PlayerState? get state => _state;
  bool get isLoaded => _state != null;

  /// Today in Vietnam time (days since 1970).
  int get today => repository.today;

  Quest? get todayQuest {
    final state = _state;
    return state == null ? null : questForDay(state.seed, today);
  }

  int get balance => _state?.balance ?? 0;
  int get streak => _state?.visibleStreak(today) ?? 0;
  int get attemptsLeft =>
      _state?.attemptsLeft(today) ?? QuestRules.attemptsPerDay;
  bool get completedToday => _state?.completedOn(today) ?? false;
  String? get passedPhotoId => _state?.passedPhotoOn(today);

  Future<void> load() => _run(repository.load);

  Future<void> recordFailedAttempt() => _run(repository.recordFailedAttempt);

  Future<void> recordPassed(String photoId) =>
      _run(() => repository.recordPassed(photoId));

  Future<QuestReward> completeQuest({
    required Quest quest,
    required int questDay,
    required String photoId,
    required String imagePath,
    required String caption,
  }) async {
    final reward = await repository.completeQuest(
      quest: quest,
      questDay: questDay,
      photoId: photoId,
      imagePath: imagePath,
      caption: caption,
    );
    _lastCompleted = reward.post;
    _set(reward.state);
    return reward;
  }

  Future<void> buy(ShopItem item) => _run(() => repository.buy(item.id));

  Future<void> equip(ShopItem item) => _run(() => repository.equip(item.id));

  Future<void> unequip(CosmeticKind kind) =>
      _run(() => repository.unequip(kind));

  Future<void> setAvatar(Uint8List jpegBytes) =>
      _run(() => repository.setAvatar(jpegBytes));

  Future<void> setMusicMuted(bool muted) =>
      _run(() => repository.setMusicMuted(muted));

  /// Re-reads the clock-dependent getters (e.g. after 00:00 in Vietnam).
  void refreshDay() => notifyListeners();

  Future<void> _run(Future<PlayerState> Function() action) async {
    _set(await action());
  }

  void _set(PlayerState state) {
    _state = state;
    notifyListeners();
  }
}
