import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';

/// Daily quest, streak and Sunbit rules.
abstract final class QuestRules {
  static const attemptsPerDay = 3;
  static const questReward = 25;
  static const streakBonus = 50;
  static const streakBonusEvery = 7;
  static const maxCaptionLength = 80;

  /// Vietnam has no daylight saving time: UTC+7 all year.
  static const vietnamOffset = Duration(hours: 7);

  /// Days since 1970-01-01 in Vietnam time. A new quest day starts at 00:00
  /// in Vietnam, whatever time zone the phone is set to.
  static int vietnamDay(DateTime now) {
    final local = now.toUtc().add(vietnamOffset);
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime.utc(1970)).inDays;
  }

  /// The streak after completing today's quest.
  static int nextStreak(int streak, int? lastCompletedDay, int today) {
    if (lastCompletedDay == today) return streak;
    if (lastCompletedDay == today - 1) return streak + 1;
    return 1;
  }

  /// The streak to show: it drops to 0 as soon as a day is missed.
  static int visibleStreak(int streak, int? lastCompletedDay, int today) {
    if (lastCompletedDay == null) return 0;
    return today - lastCompletedDay <= 1 ? streak : 0;
  }

  /// Sunbit for completing a quest that brings the streak to [newStreak].
  static int rewardFor(int newStreak) =>
      questReward +
      (newStreak > 0 && newStreak % streakBonusEvery == 0 ? streakBonus : 0);
}

/// One change to the Sunbit balance.
class LedgerEntry {
  const LedgerEntry({
    required this.amount,
    required this.reason,
    required this.at,
  });

  /// Positive when earned, negative when spent.
  final int amount;
  final String reason;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'amount': amount,
    'reason': reason,
    'at': at.toIso8601String(),
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    amount: json['amount'] as int,
    reason: json['reason'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
  );
}

/// A completed quest, posted to the profile and the feed (with music).
class QuestPost {
  const QuestPost({
    required this.id,
    required this.questId,
    required this.photoId,
    required this.imagePath,
    required this.caption,
    required this.style,
    required this.createdAt,
    required this.day,
  });

  final String id;
  final String questId;

  /// The print the post was made from (hidden from the feed as a print).
  final String photoId;
  final String imagePath;
  final String caption;
  final StyleType style;
  final DateTime createdAt;
  final int day;

  Map<String, Object?> toJson() => {
    'id': id,
    'questId': questId,
    'photoId': photoId,
    'imagePath': imagePath,
    'caption': caption,
    'style': style.name,
    'createdAt': createdAt.toIso8601String(),
    'day': day,
  };

  factory QuestPost.fromJson(Map<String, dynamic> json) => QuestPost(
    id: json['id'] as String,
    questId: json['questId'] as String,
    photoId: json['photoId'] as String,
    imagePath: json['imagePath'] as String,
    caption: json['caption'] as String? ?? '',
    style: StyleType.values.firstWhere(
      (style) => style.name == json['style'],
      orElse: () => StyleType.pixel8bit,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    day: json['day'] as int,
  );
}

/// Everything about the player that the quest, wallet and shop share. It is
/// stored as one record so a reward or purchase is saved all at once.
class PlayerState {
  const PlayerState({
    required this.seed,
    this.balance = 0,
    this.ledger = const [],
    this.streak = 0,
    this.lastCompletedDay,
    this.questDay,
    this.failedAttempts = 0,
    this.passedPhotoId,
    this.owned = const {},
    this.equippedFrame,
    this.equippedBanner,
    this.avatarPath,
    this.questPosts = const [],
    this.musicMuted = false,
  });

  /// Picks this user's quest order (see questForDay).
  final int seed;

  /// Sunbit. Never negative.
  final int balance;

  /// Newest last; trimmed to the latest [maxLedger] entries.
  final List<LedgerEntry> ledger;
  final int streak;
  final int? lastCompletedDay;

  /// The day [failedAttempts] and [passedPhotoId] belong to. On any other day
  /// they are stale and read as 0 / none.
  final int? questDay;
  final int failedAttempts;

  /// The photo that passed today's check but is not posted yet.
  final String? passedPhotoId;
  final Set<String> owned;
  final String? equippedFrame;
  final String? equippedBanner;
  final String? avatarPath;

  /// Newest first.
  final List<QuestPost> questPosts;
  final bool musicMuted;

  static const maxLedger = 100;

  bool completedOn(int day) => lastCompletedDay == day;

  int attemptsLeft(int day) => questDay == day
      ? (QuestRules.attemptsPerDay - failedAttempts).clamp(
          0,
          QuestRules.attemptsPerDay,
        )
      : QuestRules.attemptsPerDay;

  String? passedPhotoOn(int day) => questDay == day ? passedPhotoId : null;

  int visibleStreak(int day) =>
      QuestRules.visibleStreak(streak, lastCompletedDay, day);

  bool owns(String itemId) => owned.contains(itemId);

  String? equipped(CosmeticKind kind) => switch (kind) {
    CosmeticKind.frame => equippedFrame,
    CosmeticKind.banner => equippedBanner,
  };

  Loadout get loadout =>
      Loadout(frameId: equippedFrame, bannerId: equippedBanner);

  PlayerState copyWith({
    int? balance,
    List<LedgerEntry>? ledger,
    int? streak,
    int? lastCompletedDay,
    int? questDay,
    int? failedAttempts,
    String? passedPhotoId,
    bool clearPassedPhoto = false,
    Set<String>? owned,
    String? equippedFrame,
    bool clearFrame = false,
    String? equippedBanner,
    bool clearBanner = false,
    String? avatarPath,
    List<QuestPost>? questPosts,
    bool? musicMuted,
  }) => PlayerState(
    seed: seed,
    balance: balance ?? this.balance,
    ledger: ledger ?? this.ledger,
    streak: streak ?? this.streak,
    lastCompletedDay: lastCompletedDay ?? this.lastCompletedDay,
    questDay: questDay ?? this.questDay,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    passedPhotoId: clearPassedPhoto
        ? null
        : passedPhotoId ?? this.passedPhotoId,
    owned: owned ?? this.owned,
    equippedFrame: clearFrame ? null : equippedFrame ?? this.equippedFrame,
    equippedBanner: clearBanner ? null : equippedBanner ?? this.equippedBanner,
    avatarPath: avatarPath ?? this.avatarPath,
    questPosts: questPosts ?? this.questPosts,
    musicMuted: musicMuted ?? this.musicMuted,
  );

  /// Moves the per-day quest fields to [day], resetting them on a new day.
  PlayerState onDay(int day) => questDay == day
      ? this
      : PlayerState(
          seed: seed,
          balance: balance,
          ledger: ledger,
          streak: streak,
          lastCompletedDay: lastCompletedDay,
          questDay: day,
          owned: owned,
          equippedFrame: equippedFrame,
          equippedBanner: equippedBanner,
          avatarPath: avatarPath,
          questPosts: questPosts,
          musicMuted: musicMuted,
        );

  Map<String, Object?> toJson() => {
    'seed': seed,
    'balance': balance,
    'ledger': ledger.map((entry) => entry.toJson()).toList(),
    'streak': streak,
    'lastCompletedDay': lastCompletedDay,
    'questDay': questDay,
    'failedAttempts': failedAttempts,
    'passedPhotoId': passedPhotoId,
    'owned': owned.toList(),
    'equippedFrame': equippedFrame,
    'equippedBanner': equippedBanner,
    'avatarPath': avatarPath,
    'questPosts': questPosts.map((post) => post.toJson()).toList(),
    'musicMuted': musicMuted,
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    seed: json['seed'] as int,
    balance: (json['balance'] as int? ?? 0).clamp(0, 1 << 31),
    ledger: (json['ledger'] as List<dynamic>? ?? const [])
        .map((item) => LedgerEntry.fromJson(item as Map<String, dynamic>))
        .toList(),
    streak: json['streak'] as int? ?? 0,
    lastCompletedDay: json['lastCompletedDay'] as int?,
    questDay: json['questDay'] as int?,
    failedAttempts: json['failedAttempts'] as int? ?? 0,
    passedPhotoId: json['passedPhotoId'] as String?,
    owned: (json['owned'] as List<dynamic>? ?? const []).cast<String>().toSet(),
    equippedFrame: json['equippedFrame'] as String?,
    equippedBanner: json['equippedBanner'] as String?,
    avatarPath: json['avatarPath'] as String?,
    questPosts: (json['questPosts'] as List<dynamic>? ?? const [])
        .map((item) => QuestPost.fromJson(item as Map<String, dynamic>))
        .toList(),
    musicMuted: json['musicMuted'] as bool? ?? false,
  );
}
