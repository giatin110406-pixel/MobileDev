import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/language.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What went wrong with a contest action, in words.
String contestFailureText(AppLocalizations l10n, ContestFailure failure) =>
    switch (failure.kind) {
      ContestFailureKind.notFound => l10n.cfNotFound,
      ContestFailureKind.notOwner => l10n.cfNotOwner,
      ContestFailureKind.notOpen => l10n.cfNotOpen,
      ContestFailureKind.notJudging => l10n.cfNotJudging,
      ContestFailureKind.alreadySubmitted => l10n.cfAlreadySubmitted,
      ContestFailureKind.contestFull => l10n.cfContestFull,
      ContestFailureKind.canvasTooEmpty => l10n.cfCanvasTooEmpty,
      ContestFailureKind.groupTooSmall => l10n.cfGroupTooSmall,
      ContestFailureKind.noCanvas => l10n.cfNoCanvas,
      ContestFailureKind.notParticipant => l10n.cfNotParticipant,
      ContestFailureKind.ownEntry => l10n.cfOwnEntry,
      ContestFailureKind.badScore => l10n.cfBadScore,
      ContestFailureKind.empty => l10n.cfEmpty,
      ContestFailureKind.tooLong => l10n.cfTooLong,
      ContestFailureKind.tooFast => l10n.cfTooFast,
      ContestFailureKind.tooMany => l10n.cfTooMany,
      ContestFailureKind.blockedWord => l10n.cfBlockedWord,
      ContestFailureKind.tooManyReports => l10n.cfTooManyReports,
      ContestFailureKind.network => l10n.cfNetwork,
      ContestFailureKind.unknown => l10n.cfUnknown,
    };

String phaseLabel(AppLocalizations l10n, ContestPhase phase) => switch (phase) {
  ContestPhase.upcoming => l10n.phaseUpcoming,
  ContestPhase.open => l10n.phaseOpen,
  ContestPhase.judging => l10n.phaseJudging,
  ContestPhase.closed => l10n.phaseClosed,
  ContestPhase.finalized => l10n.phaseFinalized,
};

Color phaseColor(ContestPhase phase) => switch (phase) {
  ContestPhase.upcoming => NeoColors.blue,
  ContestPhase.open => NeoColors.teal,
  ContestPhase.judging => NeoColors.yellow,
  ContestPhase.closed => NeoColors.orange,
  ContestPhase.finalized => NeoColors.purple,
};

/// "1d 03:12:09" or "03:12:09".
String formatCountdown(AppLocalizations l10n, Duration left) {
  String two(int n) => n.toString().padLeft(2, '0');
  final days = left.inDays;
  final hours = left.inHours % 24;
  final clock =
      '${two(hours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  return days > 0 ? l10n.countdownDays(days, clock) : clock;
}

String _milestoneText(AppLocalizations l10n, ContestPhase next) =>
    switch (next) {
      ContestPhase.open => l10n.milestoneOpen,
      ContestPhase.judging => l10n.milestoneJudging,
      ContestPhase.closed => l10n.milestoneClosed,
      _ => '',
    };

/// A moment in the phone's time zone, e.g. "Sat 10/10 00:00".
String formatMoment(BuildContext context, DateTime time) {
  final l10n = AppLocalizations.of(context);
  final local = time.toLocal();
  final days = [
    l10n.weekdayMon,
    l10n.weekdayTue,
    l10n.weekdayWed,
    l10n.weekdayThu,
    l10n.weekdayFri,
    l10n.weekdaySat,
    l10n.weekdaySun,
  ];
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
          label: AppLocalizations.of(context).contestBannerSemantics(
            contest.weekKey,
            theme.title(vietnamese: vi),
            phaseLabel(AppLocalizations.of(context), phase),
          ),
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
                          AppLocalizations.of(context).contestBannerTitle(
                            phaseLabel(AppLocalizations.of(context), phase),
                          ),
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
                            AppLocalizations.of(context).contestTimeLeft(
                              formatCountdown(
                                AppLocalizations.of(context),
                                left,
                              ),
                              _milestoneText(
                                AppLocalizations.of(context),
                                milestone.phase,
                              ),
                            ),
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
