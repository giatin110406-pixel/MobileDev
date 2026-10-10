import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';

/// Why a quest or shop action was refused.
enum PlayerError {
  questExpired,
  alreadyDone,
  noAttempts,
  notPassed,
  captionTooLong,
  alreadyOwned,
  notOwned,
  itemNotFound,
  soldOut,
  needsNetwork,
  notEnoughSunbit,
  unknown,
}

/// A quest or shop action that the rules do not allow. The screens turn
/// [kind] into a sentence in the app's language (playerErrorText), so nothing
/// here is written in one language.
class PlayerException implements Exception {
  const PlayerException(this.kind, {this.value = 0});

  final PlayerError kind;

  /// The number the sentence needs, if any (the caption limit, the Sunbit
  /// still missing).
  final int value;

  /// For logs only.
  String get message => kind.name;

  @override
  String toString() => 'PlayerException(${kind.name})';
}

class NotEnoughSunbit extends PlayerException {
  const NotEnoughSunbit(this.missing)
    : super(PlayerError.notEnoughSunbit, value: missing);

  final int missing;
}

/// What completing a quest paid out.
class QuestReward {
  const QuestReward({
    required this.state,
    required this.post,
    required this.streak,
    required this.base,
    required this.bonus,
    this.ink = 0,
  });

  final PlayerState state;
  final QuestPost post;
  final int streak;
  final int base;
  final int bonus;

  /// Ink earned too (10 with an account, 0 on this device only).
  final int ink;

  int get total => base + bonus;
}

/// Where the player's quest, Sunbit and shop state lives: on this device
/// ([PlayerRepository]) or on the account's server.
abstract interface class PlayerGateway {
  /// Today in Vietnam time (days since 1970).
  int get today;

  Future<PlayerState> load();

  /// A photo did not show today's subject: one of today's tries is gone.
  Future<PlayerState> recordFailedAttempt();

  /// A photo passed today's check; it can be posted any time today.
  Future<PlayerState> recordPassed(String photoId);

  /// Posts today's quest photo and pays the reward (once per day).
  Future<QuestReward> completeQuest({
    required Quest quest,
    required int questDay,
    required String photoId,
    required String imagePath,
    required String caption,
  });

  Future<PlayerState> buy(String itemId);
  Future<PlayerState> equip(String itemId);
  Future<PlayerState> unequip(CosmeticKind kind);
  Future<PlayerState> setAvatar(Uint8List jpegBytes);
  Future<PlayerState> setMusicMuted(bool muted);
}

/// Stores [PlayerState] on this device. Every change goes through one queue,
/// so two quick taps can never spend the same Sunbit twice.
class PlayerRepository implements PlayerGateway {
  PlayerRepository({DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random();

  static const _key = 'player_state_v1';

  final DateTime Function() _clock;
  final Random _random;
  Future<void> _queue = Future.value();

  DateTime now() => _clock();

  @override
  int get today => QuestRules.vietnamDay(_clock());

  @override
  Future<PlayerState> load() => _serial(_read);

  /// A photo did not show today's subject: one of today's tries is gone.
  @override
  Future<PlayerState> recordFailedAttempt() => _update((state) {
    final day = today;
    _checkCanTry(state, day);
    final current = state.onDay(day);
    return current.copyWith(failedAttempts: current.failedAttempts + 1);
  });

  /// A photo passed today's check; it can be posted any time today.
  @override
  Future<PlayerState> recordPassed(String photoId) => _update((state) {
    final day = today;
    _checkCanTry(state, day);
    return state.onDay(day).copyWith(passedPhotoId: photoId);
  });

  /// Posts today's quest photo and pays the reward (once per day). Fails if
  /// the Vietnam day changed since the photo was taken ([questDay]).
  @override
  Future<QuestReward> completeQuest({
    required Quest quest,
    required int questDay,
    required String photoId,
    required String imagePath,
    required String caption,
  }) async {
    late QuestReward reward;
    await _update((state) {
      final day = today;
      if (questDay != day) {
        throw const PlayerException(PlayerError.questExpired);
      }
      if (state.completedOn(day)) {
        throw const PlayerException(PlayerError.alreadyDone);
      }
      final text = caption.trim();
      if (text.characters.length > QuestRules.maxCaptionLength) {
        throw const PlayerException(
          PlayerError.captionTooLong,
          value: QuestRules.maxCaptionLength,
        );
      }
      final at = _clock();
      final streak = QuestRules.nextStreak(
        state.streak,
        state.lastCompletedDay,
        day,
      );
      const base = QuestRules.questReward;
      final bonus = QuestRules.rewardFor(streak) - base;
      final post = QuestPost(
        id: at.microsecondsSinceEpoch.toString(),
        questId: quest.id,
        photoId: photoId,
        imagePath: imagePath,
        caption: text,
        style: quest.style,
        createdAt: at,
        day: day,
      );
      final next = state
          .onDay(day)
          .copyWith(
            balance: state.balance + base + bonus,
            ledger: _trim([
              ...state.ledger,
              LedgerEntry(
                amount: base,
                reason: 'Nhiệm vụ: ${quest.subject}',
                at: at,
              ),
              if (bonus > 0)
                LedgerEntry(
                  amount: bonus,
                  reason: 'Thưởng streak $streak ngày',
                  at: at,
                ),
            ]),
            streak: streak,
            lastCompletedDay: day,
            clearPassedPhoto: true,
            questPosts: [post, ...state.questPosts],
          );
      reward = QuestReward(
        state: next,
        post: post,
        streak: streak,
        base: base,
        bonus: bonus,
      );
      return next;
    });
    return reward;
  }

  @override
  Future<PlayerState> buy(String itemId) => _update((state) {
    final item = _item(itemId);
    if (state.owns(item.id)) {
      throw const PlayerException(PlayerError.alreadyOwned);
    }
    if (state.balance < item.price) {
      throw NotEnoughSunbit(item.price - state.balance);
    }
    return state.copyWith(
      balance: state.balance - item.price,
      ledger: _trim([
        ...state.ledger,
        LedgerEntry(
          amount: -item.price,
          reason: 'Mua: ${item.name}',
          at: _clock(),
        ),
      ]),
      owned: {...state.owned, item.id},
    );
  });

  /// Wears an owned item; it replaces whatever of its kind was worn. Free.
  @override
  Future<PlayerState> equip(String itemId) => _update((state) {
    final item = _item(itemId);
    if (!state.owns(item.id)) {
      throw const PlayerException(PlayerError.notOwned);
    }
    return switch (item.kind) {
      CosmeticKind.frame => state.copyWith(equippedFrame: item.id),
      CosmeticKind.banner => state.copyWith(equippedBanner: item.id),
    };
  });

  @override
  Future<PlayerState> unequip(CosmeticKind kind) => _update(
    (state) => switch (kind) {
      CosmeticKind.frame => state.copyWith(clearFrame: true),
      CosmeticKind.banner => state.copyWith(clearBanner: true),
    },
  );

  /// Saves [jpegBytes] as the profile picture (replacing the old one).
  @override
  Future<PlayerState> setAvatar(Uint8List jpegBytes) async {
    final documents = await getApplicationDocumentsDirectory();
    final path =
        '${documents.path}${Platform.pathSeparator}avatar_${_clock().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(jpegBytes, flush: true);
    String? previous;
    final state = await _update((state) {
      previous = state.avatarPath;
      return state.copyWith(avatarPath: path);
    });
    if (previous != null && previous != path) {
      try {
        await File(previous!).delete();
      } catch (_) {}
    }
    return state;
  }

  @override
  Future<PlayerState> setMusicMuted(bool muted) =>
      _update((state) => state.copyWith(musicMuted: muted));

  // -- internals -------------------------------------------------------------

  void _checkCanTry(PlayerState state, int day) {
    if (state.completedOn(day)) {
      throw const PlayerException(PlayerError.alreadyDone);
    }
    if (state.attemptsLeft(day) == 0) {
      throw const PlayerException(PlayerError.noAttempts);
    }
  }

  ShopItem _item(String id) {
    final item = shopItemById(id);
    if (item == null) throw const PlayerException(PlayerError.itemNotFound);
    return item;
  }

  List<LedgerEntry> _trim(List<LedgerEntry> ledger) =>
      ledger.length <= PlayerState.maxLedger
      ? ledger
      : ledger.sublist(ledger.length - PlayerState.maxLedger);

  Future<PlayerState> _update(PlayerState Function(PlayerState) change) =>
      _serial(() async {
        final next = change(await _read());
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_key, jsonEncode(next.toJson()));
        return next;
      });

  Future<PlayerState> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);
    if (stored != null) {
      return PlayerState.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    }
    final fresh = PlayerState(seed: _random.nextInt(0x7FFFFFFF));
    await preferences.setString(_key, jsonEncode(fresh.toJson()));
    return fresh;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
