import 'dart:io';
import 'dart:typed_data';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Calls one of the server's functions (a Supabase RPC) and returns its JSON.
typedef RpcCall =
    Future<dynamic> Function(String name, Map<String, dynamic>? params);

/// Turns the server's player document (see `player_json` in the player
/// migration) into the state the app shows. [avatarPath] is this phone's copy
/// of the profile photo.
PlayerState playerStateFromServer(
  Map<String, dynamic> json, {
  String? avatarPath,
}) => PlayerState(
  seed: json['seed'] as int,
  balance: (json['balance'] as int? ?? 0).clamp(0, 1 << 31),
  inkBalance: (json['ink_balance'] as int? ?? 0).clamp(0, 1 << 31),
  streak: json['streak'] as int? ?? 0,
  lastCompletedDay: json['last_completed_day'] as int?,
  questDay: json['quest_day'] as int?,
  failedAttempts: json['failed_attempts'] as int? ?? 0,
  passedPhotoId: json['passed_photo_id'] as String?,
  musicMuted: json['music_muted'] as bool? ?? false,
  owned: {for (final id in json['owned'] as List<dynamic>? ?? const []) '$id'},
  equippedFrame: json['frame_id'] as String?,
  equippedBanner: json['banner_id'] as String?,
  avatarPath: avatarPath,
  ledger: [
    for (final row in json['ledger'] as List<dynamic>? ?? const [])
      LedgerEntry(
        amount: (row as Map<String, dynamic>)['amount'] as int,
        reason: row['reason'] as String? ?? '',
        at: DateTime.parse(row['at'] as String),
      ),
  ],
);

/// The same quest, streak, Sunbit and shop rules as [PlayerRepository], but
/// kept on the server: Sunbit follows the account to any phone, and friends
/// see the frame and banner you wear.
class ServerPlayerRepository implements PlayerGateway {
  ServerPlayerRepository({
    required this.userId,
    DateTime Function()? clock,
    RpcCall? rpc,
  }) : _clock = clock ?? DateTime.now,
       _call = rpc ?? _supabaseRpc;

  final String userId;
  final DateTime Function() _clock;
  final RpcCall _call;
  PlayerState? _last;

  /// This phone's copy of the profile photo (a file path), if it has one.
  String? _avatarPath;

  /// Whole days the phone's clock is off from the server's (usually 0).
  int _dayShift = 0;

  static Future<dynamic> _supabaseRpc(
    String name,
    Map<String, dynamic>? params,
  ) => Backend.client.rpc(name, params: params);

  String get _avatarKey => 'avatar_path_$userId';

  @override
  int get today => QuestRules.vietnamDay(_clock()) + _dayShift;

  @override
  Future<PlayerState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_avatarKey);
    _avatarPath = saved != null && File(saved).existsSync() ? saved : null;
    final json = await _rpc('get_player_state');
    final serverToday = json['today'] as int?;
    if (serverToday != null) {
      _dayShift = serverToday - QuestRules.vietnamDay(_clock());
    }
    return _adopt(json);
  }

  @override
  Future<PlayerState> recordFailedAttempt() async =>
      _adopt(await _rpc('record_quest_attempt', {'p_passed': false}));

  @override
  Future<PlayerState> recordPassed(String photoId) async => _adopt(
    await _rpc('record_quest_attempt', {
      'p_passed': true,
      'p_photo_id': photoId,
    }),
  );

  @override
  Future<QuestReward> completeQuest({
    required Quest quest,
    required int questDay,
    required String photoId,
    required String imagePath,
    required String caption,
  }) async {
    final text = caption.trim();
    if (text.length > QuestRules.maxCaptionLength) {
      throw const PlayerException(
        PlayerError.captionTooLong,
        value: QuestRules.maxCaptionLength,
      );
    }
    final json = await _rpc('complete_quest', {
      'p_day': questDay,
      'p_quest_id': quest.id,
    });
    final state = _adopt(json['state'] as Map<String, dynamic>);
    final at = _clock();
    return QuestReward(
      state: state,
      post: QuestPost(
        id: at.microsecondsSinceEpoch.toString(),
        questId: quest.id,
        photoId: photoId,
        imagePath: imagePath,
        caption: text,
        style: quest.style,
        createdAt: at,
        day: questDay,
      ),
      streak: json['streak'] as int,
      base: json['base'] as int,
      bonus: json['bonus'] as int,
      ink: json['ink'] as int? ?? 0,
    );
  }

  @override
  Future<PlayerState> buy(String itemId) async {
    final item = shopItemById(itemId);
    final known = _last;
    if (item != null && known != null && known.balance < item.price) {
      throw NotEnoughSunbit(item.price - known.balance);
    }
    return _adopt(await _rpc('buy_item', {'p_item': itemId}));
  }

  @override
  Future<PlayerState> equip(String itemId) async =>
      _adopt(await _rpc('equip_item', {'p_item': itemId}));

  @override
  Future<PlayerState> unequip(CosmeticKind kind) async =>
      _adopt(await _rpc('unequip_item', {'p_kind': kind.name}));

  @override
  Future<PlayerState> setMusicMuted(bool muted) async =>
      _adopt(await _rpc('set_music_muted', {'p_muted': muted}));

  /// Keeps a copy of the profile photo on this phone so it shows at once.
  /// (The upload to the server is done by the account session.)
  @override
  Future<PlayerState> setAvatar(Uint8List jpegBytes) async {
    final documents = await getApplicationDocumentsDirectory();
    final path =
        '${documents.path}${Platform.pathSeparator}avatar_${_clock().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(jpegBytes, flush: true);
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getString(_avatarKey);
    await preferences.setString(_avatarKey, path);
    if (previous != null && previous != path) {
      try {
        await File(previous).delete();
      } catch (_) {}
    }
    _avatarPath = path;
    final state = _last;
    if (state == null) return load();
    return _last = state.copyWith(avatarPath: path);
  }

  PlayerState _adopt(Map<String, dynamic> json) =>
      _last = playerStateFromServer(json, avatarPath: _avatarPath);

  Future<Map<String, dynamic>> _rpc(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      final result = await _call(name, params);
      return Map<String, dynamic>.from(result as Map);
    } on sb.PostgrestException catch (error) {
      throw playerFailureFor(error.message, known: _last);
    } on PlayerException {
      rethrow;
    } catch (_) {
      throw const PlayerException(PlayerError.needsNetwork);
    }
  }
}

/// The failure for a rule the server refused (its short error code).
PlayerException playerFailureFor(String code, {PlayerState? known}) {
  return switch (code) {
    'already_done' => const PlayerException(PlayerError.alreadyDone),
    'no_attempts' => const PlayerException(PlayerError.noAttempts),
    'not_passed' => const PlayerException(PlayerError.notPassed),
    'expired' => const PlayerException(PlayerError.questExpired),
    'already_owned' => const PlayerException(PlayerError.alreadyOwned),
    'not_owned' => const PlayerException(PlayerError.notOwned),
    'not_found' => const PlayerException(PlayerError.itemNotFound),
    'insufficient_funds' => const NotEnoughSunbit(1),
    _ => const PlayerException(PlayerError.unknown),
  };
}
