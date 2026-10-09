import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';

/// Where today's quest stands for the user.
enum QuestStatus { open, passed, outOfTries, done }

QuestStatus questStatusOf(PlayerStore store) {
  if (store.completedToday) return QuestStatus.done;
  if (store.passedPhotoId != null) return QuestStatus.passed;
  if (store.attemptsLeft == 0) return QuestStatus.outOfTries;
  return QuestStatus.open;
}

Color questStyleColor(StyleType style) =>
    style == StyleType.vanGogh ? NeoColors.yellow : NeoColors.teal;

/// One line on the camera screen: today's subject and how it is going. Tap it
/// for the story and the start button.
class QuestStrip extends StatelessWidget {
  const QuestStrip({super.key, required this.store, required this.onTap});

  final PlayerStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quest = store.todayQuest;
    if (quest == null) return const SizedBox(height: 52);
    final status = questStatusOf(store);
    return Semantics(
      button: true,
      label: 'Nhiệm vụ hôm nay: chụp ${quest.subject}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 52,
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
          decoration: NeoTheme.panel(
            color: status == QuestStatus.done
                ? NeoColors.teal
                : NeoColors.surface,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: questStyleColor(quest.style),
                  border: Border.all(color: NeoColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(quest.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'NHIỆM VỤ HÔM NAY · ${quest.style.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chụp ${quest.subject}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              switch (status) {
                QuestStatus.done => const NeoLabel(
                  'XONG ✓',
                  color: NeoColors.surface,
                ),
                QuestStatus.passed => const NeoLabel(
                  'ĐĂNG NGAY',
                  color: NeoColors.pink,
                ),
                QuestStatus.outOfTries => const NeoLabel(
                  'HẾT LƯỢT',
                  color: NeoColors.switchOff,
                ),
                QuestStatus.open => AttemptDots(left: store.attemptsLeft),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// ●●○ — tries left today.
class AttemptDots extends StatelessWidget {
  const AttemptDots({super.key, required this.left});

  final int left;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Còn $left lượt thử',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < QuestRules.attemptsPerDay; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: i < left ? NeoColors.pink : NeoColors.switchOff,
              border: Border.all(color: NeoColors.ink, width: 2),
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}

/// What the user chose in the quest sheet.
enum QuestSheetAction { start, post }

/// Today's quest in full: subject, style, the true story, tries, reward and
/// one button that matches where the quest stands.
Future<QuestSheetAction?> showQuestSheet(
  BuildContext context,
  PlayerStore store,
) => showModalBottomSheet<QuestSheetAction>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => _QuestSheet(store: store),
  ),
);

class _QuestSheet extends StatelessWidget {
  const _QuestSheet({required this.store});

  final PlayerStore store;

  @override
  Widget build(BuildContext context) {
    final quest = store.todayQuest;
    final state = store.state;
    if (quest == null || state == null) return const SizedBox.shrink();
    final status = questStatusOf(store);
    final nextStreak = QuestRules.nextStreak(
      state.streak,
      state.lastCompletedDay,
      store.today,
    );
    final bonus = QuestRules.rewardFor(nextStreak) - QuestRules.questReward;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NeoLabel(
                    quest.style.label,
                    color: questStyleColor(quest.style),
                  ),
                  const SizedBox(width: 8),
                  StreakChip(streak: store.streak),
                  const Spacer(),
                  if (status == QuestStatus.open)
                    AttemptDots(left: store.attemptsLeft),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'HÔM NAY, HÃY CHỤP',
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${quest.emoji} ${_capitalized(quest.subject)}',
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: NeoTheme.panel(
                  color: questStyleColor(quest.style).withValues(alpha: 0.45),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.storyTitle,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quest.story,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const SunbitCoin(size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bonus > 0
                          ? '+${QuestRules.questReward} Sunbit, +$bonus thưởng streak $nextStreak ngày!'
                          : '+${QuestRules.questReward} Sunbit · thêm +${QuestRules.streakBonus} mỗi ${QuestRules.streakBonusEvery} ngày streak',
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Chỉ chụp trực tiếp bằng camera · 3 lượt thử mỗi ngày · Ngày mới bắt đầu lúc 00:00 giờ Việt Nam',
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 10,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              switch (status) {
                QuestStatus.open => NeoButton(
                  expand: true,
                  label: 'BẮT ĐẦU CHỤP',
                  icon: Icons.photo_camera_outlined,
                  variant: NeoButtonVariant.primary,
                  onPressed: () =>
                      Navigator.pop(context, QuestSheetAction.start),
                ),
                QuestStatus.passed => NeoButton(
                  expand: true,
                  label: 'ĐĂNG ẢNH NHIỆM VỤ',
                  icon: Icons.send_rounded,
                  variant: NeoButtonVariant.primary,
                  onPressed: () =>
                      Navigator.pop(context, QuestSheetAction.post),
                ),
                QuestStatus.outOfTries => const NeoButton(
                  expand: true,
                  label: 'HẾT LƯỢT HÔM NAY',
                  icon: Icons.lock_outline,
                  variant: NeoButtonVariant.outline,
                  onPressed: null,
                ),
                QuestStatus.done => const NeoButton(
                  expand: true,
                  label: 'ĐÃ HOÀN THÀNH ✓',
                  icon: Icons.check,
                  variant: NeoButtonVariant.accent,
                  onPressed: null,
                ),
              },
              if (status == QuestStatus.outOfTries ||
                  status == QuestStatus.done) ...[
                const SizedBox(height: 10),
                Text(
                  status == QuestStatus.done
                      ? 'Nhiệm vụ mới sẽ đến lúc 00:00. Hẹn gặp lại!'
                      : 'Bạn đã dùng hết 3 lượt thử. Nhiệm vụ mới sẽ đến lúc 00:00.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalized(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
