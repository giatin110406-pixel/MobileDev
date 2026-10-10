import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_progress.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_screen.dart';
import 'package:neo_brutalism_locket/features/contest/results_screen.dart';
import 'package:neo_brutalism_locket/features/contest/submit_entry_sheet.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

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
      if (!mounted) return;
      showNeoSnack(
        context,
        AppLocalizations.of(context).contestSubmittedSnack(seq),
      );
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
                      tooltip: AppLocalizations.of(context).backTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).contestTitle,
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
                  Text(
                    AppLocalizations.of(context).contestLoadFailed,
                    style: TextStyle(
                      color: NeoColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  NeoButton(
                    label: AppLocalizations.of(context).retry,
                    onPressed: store.refresh,
                  ),
                ],
              ),
      );
    }
    if (overview == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).contestNone,
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
              child: Text(
                AppLocalizations.of(context).contestStale,
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
          if (contest.acceptedCount > 0) ...[
            const SizedBox(height: 4),
            NeoButton(
              label: AppLocalizations.of(
                context,
              ).contestEnterGallery(contest.acceptedCount),
              icon: Icons.museum_outlined,
              expand: true,
              variant: NeoButtonVariant.secondary,
              onPressed: _openGallery,
            ),
          ],
          if (phase == ContestPhase.finalized) ...[
            const SizedBox(height: 10),
            NeoButton(
              label: AppLocalizations.of(context).contestSeeResults,
              icon: Icons.emoji_events_outlined,
              expand: true,
              variant: NeoButtonVariant.accent,
              onPressed: () => _openResults(contest.id),
            ),
          ],
          if (overview.previous != null) ...[
            const SizedBox(height: 10),
            NeoButton(
              label: AppLocalizations.of(context)
                  .contestPrevResults(
                    vi
                        ? overview.previous!.titleVi
                        : overview.previous!.titleEn,
                  )
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
              NeoLabel(
                phaseLabel(AppLocalizations.of(context), phase),
                color: phaseColor(phase),
              ),
              Expanded(
                child:
                    phase == ContestPhase.open || phase == ContestPhase.judging
                    ? Text(
                        AppLocalizations.of(context).contestEntriesCount(
                          contest.acceptedCount,
                          contest.maxEntries,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (left != null && milestone != null) ...[
            const SizedBox(height: 12),
            Text(
              formatCountdown(AppLocalizations.of(context), left),
              style: const TextStyle(
                fontFamily: NeoFont.display,
                color: NeoColors.ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              AppLocalizations.of(
                context,
              ).contestCountdownUntil(_until(milestone.phase)),
              style: const TextStyle(
                color: NeoColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _line(
            AppLocalizations.of(context).contestLineOpens,
            formatMoment(context, contest.opensAt),
          ),
          _line(
            AppLocalizations.of(context).contestLineJudging,
            AppLocalizations.of(context).contestLineJudgingNote(
              formatMoment(context, contest.submitClosesAt),
            ),
          ),
          _line(
            AppLocalizations.of(context).contestLineEnds,
            AppLocalizations.of(
              context,
            ).contestLineEndsNote(formatMoment(context, contest.endsAt)),
          ),
        ],
      ),
    );
  }

  String _until(ContestPhase next) => switch (next) {
    ContestPhase.open => AppLocalizations.of(context).contestUntilOpen,
    ContestPhase.judging => AppLocalizations.of(context).contestUntilJudging,
    ContestPhase.closed => AppLocalizations.of(context).contestUntilClosed,
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
            AppLocalizations.of(
              context,
            ).contestMyEntry(mine.groupName, mine.seq),
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
                    ? AppLocalizations.of(context).contestNothingToRate
                    : AppLocalizations.of(
                        context,
                      ).contestRatedProgress(done, needed),
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).contestVoteRule,
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
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              AppLocalizations.of(context).contestOnlyOwner,
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
                          ? AppLocalizations.of(context).contestGroupSubmitted
                          : phase == ContestPhase.open
                          ? AppLocalizations.of(context).contestOwnerHint
                          : AppLocalizations.of(context).contestOpensAt(
                              formatMoment(context, overview.contest.opensAt),
                            ),
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
                  label: AppLocalizations.of(context).contestSubmitButton,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).contestRulesTitle,
          style: TextStyle(
            color: NeoColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).contestRules,
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
