import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';

bool isVietnamese(BuildContext context) =>
    Localizations.localeOf(context).languageCode != 'en';

/// What went wrong with a contest action, in words.
String contestFailureText(ContestFailure failure) => switch (failure.kind) {
  ContestFailureKind.notFound => 'Không tìm thấy bài dự thi.',
  ContestFailureKind.notOwner => 'Chỉ trưởng nhóm mới nộp bài được.',
  ContestFailureKind.notOpen => 'Chưa đến giờ nộp bài, hoặc đã hết giờ nộp.',
  ContestFailureKind.notJudging => 'Hiện chưa phải lúc chấm điểm.',
  ContestFailureKind.alreadySubmitted => 'Nhóm này đã nộp bài tuần này rồi.',
  ContestFailureKind.contestFull =>
    'Gallery tuần này đã đủ 100 bài. Hẹn bạn tuần sau!',
  ContestFailureKind.canvasTooEmpty =>
    'Canvas còn quá trống. Hãy vẽ thêm rồi nộp nhé.',
  ContestFailureKind.groupTooSmall => 'Nhóm cần ít nhất 2 người để dự thi.',
  ContestFailureKind.noCanvas => 'Nhóm chưa có canvas.',
  ContestFailureKind.notParticipant =>
    'Chỉ thành viên các nhóm có bài dự thi mới chấm và bình luận được.',
  ContestFailureKind.ownEntry => 'Bạn không chấm được bài của nhóm mình.',
  ContestFailureKind.badScore => 'Điểm phải từ 1 đến 5 sao.',
  ContestFailureKind.empty => 'Hãy nhập nội dung.',
  ContestFailureKind.tooLong => 'Bình luận tối đa 200 ký tự.',
  ContestFailureKind.tooFast => 'Chậm lại một chút rồi bình luận tiếp nhé.',
  ContestFailureKind.tooMany => 'Bạn đã bình luận đủ số lần cho tuần này.',
  ContestFailureKind.blockedWord => 'Bình luận có từ không phù hợp.',
  ContestFailureKind.tooManyReports => 'Hôm nay bạn đã báo cáo quá nhiều.',
  ContestFailureKind.network => 'Không kết nối được. Thử lại nhé.',
  ContestFailureKind.unknown => 'Có lỗi xảy ra. Thử lại nhé.',
};

String phaseLabel(ContestPhase phase) => switch (phase) {
  ContestPhase.upcoming => 'SẮP DIỄN RA',
  ContestPhase.open => 'ĐANG NHẬN BÀI',
  ContestPhase.judging => 'ĐANG CHẤM ĐIỂM',
  ContestPhase.closed => 'ĐANG TỔNG KẾT',
  ContestPhase.finalized => 'ĐÃ CÓ KẾT QUẢ',
};

Color phaseColor(ContestPhase phase) => switch (phase) {
  ContestPhase.upcoming => NeoColors.blue,
  ContestPhase.open => NeoColors.teal,
  ContestPhase.judging => NeoColors.yellow,
  ContestPhase.closed => NeoColors.orange,
  ContestPhase.finalized => NeoColors.purple,
};

/// "1 ngày 03:12:09" or "03:12:09".
String formatCountdown(Duration left) {
  String two(int n) => n.toString().padLeft(2, '0');
  final days = left.inDays;
  final hours = left.inHours % 24;
  final clock =
      '${two(hours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  return days > 0 ? '$days ngày $clock' : clock;
}

String _milestoneText(ContestPhase next) => switch (next) {
  ContestPhase.open => 'đến giờ nhận bài',
  ContestPhase.judging => 'hết giờ nhận bài, bắt đầu chấm',
  ContestPhase.closed => 'chốt kết quả',
  _ => '',
};

/// A moment in the phone's time zone, e.g. "Th 7 10/10 00:00".
String formatMoment(DateTime time) {
  final local = time.toLocal();
  const days = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${days[local.weekday - 1]} ${local.day}/${local.month} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// The card at the top of the group list: this week's theme and where the
/// contest stands. Tap to open the contest screen.
class ContestBanner extends StatelessWidget {
  const ContestBanner({required this.store, required this.onTap, super.key});

  final ContestStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = store.theme;
        final contest = store.contest;
        if (theme == null || contest == null) {
          return const SizedBox.shrink();
        }
        final phase = store.phase;
        final left = store.timeLeft;
        final milestone = store.nextMilestone;
        final vi = isVietnamese(context);
        return Semantics(
          button: true,
          label:
              'Cuộc thi tuần ${contest.weekKey}: ${theme.title(vietnamese: vi)}. '
              '${phaseLabel(phase)}',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: NeoTheme.panel(color: phaseColor(phase)),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUỘC THI TUẦN · ${phaseLabel(phase)}',
                          style: const TextStyle(
                            color: NeoColors.ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          theme.title(vietnamese: vi),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NeoColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (left != null && milestone != null)
                          Text(
                            'Còn ${formatCountdown(left)} ${_milestoneText(milestone.phase)}',
                            style: const TextStyle(
                              color: NeoColors.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (phase == ContestPhase.open ||
                      phase == ContestPhase.judging)
                    NeoLabel(
                      '${contest.acceptedCount}/${contest.maxEntries}',
                      color: NeoColors.surface,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
