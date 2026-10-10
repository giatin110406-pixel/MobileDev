import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_progress.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_screen.dart';
import 'package:neo_brutalism_locket/features/contest/hall_of_fame_screen.dart';
import 'package:neo_brutalism_locket/features/contest/results_screen.dart';
import 'package:neo_brutalism_locket/features/contest/submit_entry_sheet.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';

/// This week's contest: the theme, the clock, how to enter, and the way in to
/// the Gallery.
class ContestScreen extends StatefulWidget {
  const ContestScreen({
    required this.store,
    required this.canvases,
    this.safety,
    super.key,
  });

  final ContestStore store;
  final CanvasRepository canvases;
  final SafetyRepository? safety;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.startTicking();
    // Not during the build: the store tells its listeners as it starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.store.refresh();
    });
  }

  @override
  void dispose() {
    widget.store.stopTicking();
    super.dispose();
  }

  void _openGallery() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => GalleryScreen(
        repository: widget.store.repository,
        title:
            widget.store.theme?.title(vietnamese: isVietnamese(context)) ??
            'Gallery',
        contestId: widget.store.contest?.id,
      ),
    ),
  );

  void _openHall() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => HallOfFameScreen(
        repository: widget.store.repository,
        safety: widget.safety,
      ),
    ),
  );

  void _openResults(String contestId) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ResultsScreen(
        repository: widget.store.repository,
        contestId: contestId,
      ),
    ),
  );

  Future<void> _submit(OwnedGroup group) => showSubmitEntrySheet(
    context,
    store: widget.store,
    group: group,
    canvases: widget.canvases,
    onSubmitted: (seq) {
      if (mounted) showNeoSnack(context, 'Đã nộp! Bài của bạn là số $seq.');
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    NeoIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cuộc thi tuần',
                        style: TextStyle(
                          fontFamily: NeoFont.display,
                          color: NeoColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final store = widget.store;
    final overview = store.overview;
    if (!store.isLoaded) {
      return Center(
        child: store.error == null
            ? const CircularProgressIndicator(color: NeoColors.ink)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Không tải được cuộc thi.',
                    style: TextStyle(
                      color: NeoColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  NeoButton(label: 'THỬ LẠI', onPressed: store.refresh),
                ],
              ),
      );
    }
    if (overview == null) {
      return const Center(
        child: Text(
          'Chưa có cuộc thi nào.',
          style: TextStyle(color: NeoColors.ink, fontWeight: FontWeight.w700),
        ),
      );
    }
    final vi = isVietnamese(context);
    final contest = overview.contest;
    final theme = overview.theme;
    final phase = store.phase;
    final left = store.timeLeft;
    final milestone = store.nextMilestone;
    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (store.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: NeoTheme.panel(color: NeoColors.orange),
              child: const Text(
                'Không cập nhật được. Đang hiện dữ liệu cũ.',
                style: TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: NeoTheme.panel(color: phaseColor(phase)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NeoLabel(
                      theme.category == 'vangogh' ? 'VAN GOGH' : '8-BIT',
                      color: NeoColors.surface,
                    ),
                    const SizedBox(width: 8),
                    NeoLabel(contest.weekKey, color: NeoColors.surface),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  theme.title(vietnamese: vi),
                  style: const TextStyle(
                    fontFamily: NeoFont.display,
                    color: NeoColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  theme.brief(vietnamese: vi),
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _statusCard(contest, phase, left, milestone),
          const SizedBox(height: 14),
          ..._entryCards(overview, phase),
          const SizedBox(height: 4),
          NeoButton(
            label: contest.acceptedCount > 0
                ? 'VÀO GALLERY (${contest.acceptedCount} BÀI)'
                : 'VÀO GALLERY',
            icon: Icons.museum_outlined,
            expand: true,
            variant: NeoButtonVariant.secondary,
            onPressed: _openGallery,
          ),
          const SizedBox(height: 10),
          NeoButton(
            label: 'HALL OF FAME',
            icon: Icons.emoji_events_outlined,
            expand: true,
            variant: NeoButtonVariant.accent,
            onPressed: _openHall,
          ),
          if (phase == ContestPhase.finalized) ...[
            const SizedBox(height: 10),
            NeoButton(
              label: 'XEM KẾT QUẢ',
              icon: Icons.emoji_events_outlined,
              expand: true,
              variant: NeoButtonVariant.accent,
              onPressed: () => _openResults(contest.id),
            ),
          ],
          if (overview.previous != null) ...[
            const SizedBox(height: 10),
            NeoButton(
              label:
                  'KẾT QUẢ TUẦN TRƯỚC: ${vi ? overview.previous!.titleVi : overview.previous!.titleEn}'
                      .toUpperCase(),
              icon: Icons.history,
              expand: true,
              variant: NeoButtonVariant.outline,
              onPressed: () => _openResults(overview.previous!.id),
            ),
          ],
          const SizedBox(height: 18),
          const _Rules(),
        ],
      ),
    );
  }

  Widget _statusCard(
    ContestInfo contest,
    ContestPhase phase,
    Duration? left,
    ContestMilestone? milestone,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NeoTheme.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeoLabel(phaseLabel(phase), color: phaseColor(phase)),
              const Spacer(),
              if (phase == ContestPhase.open || phase == ContestPhase.judging)
                Text(
                  '${contest.acceptedCount}/${contest.maxEntries} bài',
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (left != null && milestone != null) ...[
            const SizedBox(height: 12),
            Text(
              formatCountdown(left),
              style: const TextStyle(
                fontFamily: NeoFont.display,
                color: NeoColors.ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'cho đến khi ${_until(milestone.phase)}',
              style: const TextStyle(
                color: NeoColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _line('Nhận bài từ', formatMoment(contest.opensAt)),
          _line(
            'Chấm điểm từ',
            '${formatMoment(contest.submitClosesAt)} (hoặc khi đủ 100 bài)',
          ),
          _line(
            'Chốt kết quả',
            '${formatMoment(contest.endsAt)} (23:59 CN giờ Việt Nam)',
          ),
        ],
      ),
    );
  }

  String _until(ContestPhase next) => switch (next) {
    ContestPhase.open => 'bắt đầu nhận bài',
    ContestPhase.judging => 'hết giờ nhận bài và bắt đầu chấm',
    ContestPhase.closed => 'chốt kết quả',
    _ => '',
  };

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  /// What I can do now: enter my groups, or rate if my group entered.
  List<Widget> _entryCards(ContestOverview overview, ContestPhase phase) {
    final cards = <Widget>[];
    final mine = overview.myEntry;
    if (mine != null) {
      cards.add(
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: NeoTheme.panel(color: NeoColors.teal),
          child: Text(
            'Nhóm "${mine.groupName}" đã dự thi, bài số ${mine.seq}.',
            style: const TextStyle(
              color: NeoColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    if (phase == ContestPhase.judging && overview.participant) {
      final needed = overview.votesNeeded;
      final done = overview.myVotes;
      cards.add(
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: NeoTheme.panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                needed == 0
                    ? 'Chưa có bài của nhóm khác để chấm.'
                    : 'Bạn đã chấm $done/$needed bài',
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Phiếu của bạn chỉ được tính khi chấm đủ số bài này, '
                'và tài khoản đã đủ 7 ngày tuổi.',
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (needed > 0) ...[
                const SizedBox(height: 8),
                NeoProgress(
                  value: (done / needed).clamp(0, 1).toDouble(),
                  showPercent: false,
                  height: 14,
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (overview.ownerGroups.isEmpty) {
      if (phase == ContestPhase.open && mine == null) {
        cards.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Chỉ trưởng nhóm mới nộp bài được. Hãy nhờ trưởng nhóm của bạn.',
              style: TextStyle(
                color: NeoColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      return cards;
    }
    for (final group in overview.ownerGroups) {
      final canSubmit = phase == ContestPhase.open && !group.submitted;
      cards.add(
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: NeoTheme.panel(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      group.submitted
                          ? 'Đã nộp bài tuần này'
                          : phase == ContestPhase.open
                          ? 'Bạn là trưởng nhóm: nộp canvas để dự thi'
                          : 'Nhận bài vào ${formatMoment(overview.contest.opensAt)}',
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!group.submitted)
                NeoButton(
                  label: 'NỘP BÀI',
                  icon: Icons.upload_outlined,
                  onPressed: canSubmit ? () => _submit(group) : null,
                ),
            ],
          ),
        ),
      );
    }
    return cards;
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LUẬT CHƠI',
          style: TextStyle(
            color: NeoColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '• Trưởng nhóm nộp canvas của nhóm, mỗi nhóm một bài.\n'
          '• Chỉ 100 bài nộp nhanh nhất được vào Gallery.\n'
          '• Thành viên các nhóm có bài dự thi chấm 1–5 sao và bình luận '
          'bài của nhóm khác.\n'
          '• Điểm xếp hạng là trung bình có hiệu chỉnh (Bayes), nên một vài '
          'phiếu 5 sao không đủ để vượt lên.\n'
          '• Mọi thời điểm tính theo giờ Việt Nam (UTC+7).',
          style: TextStyle(
            color: NeoColors.ink,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
