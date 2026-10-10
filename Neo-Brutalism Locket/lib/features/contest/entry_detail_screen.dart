import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/entry_export.dart';
import 'package:neo_brutalism_locket/features/contest/entry_store.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

const _reactions = ['🔥', '😍', '👏', '🎨', '😮'];

/// One entry, up close: the picture, who made it, my rating (1 to 5 stars),
/// reactions and comments. Pops with the entry (so the Gallery shows my rating).
class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({
    required this.repository,
    required this.entry,
    this.safety,
    this.exporter = const DeviceEntryExporter(),
    super.key,
  });

  final ContestRepository repository;
  final GalleryEntry entry;
  final SafetyRepository? safety;

  /// Saves or shares the picture (the phone's by default).
  final EntryExporter exporter;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late final EntryStore _store = EntryStore(widget.repository, widget.entry);
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _input.dispose();
    _store.dispose();
    super.dispose();
  }

  void _tell(Object error) {
    if (!mounted) return;
    showNeoSnack(
      context,
      error is ContestFailure
          ? contestFailureText(AppLocalizations.of(context), error)
          : AppLocalizations.of(context).cfUnknown,
    );
  }

  Future<void> _rate(int score) async {
    try {
      await _store.rate(score);
    } on ContestFailure catch (failure) {
      _tell(failure);
    }
  }

  Future<void> _react(String emoji) async {
    try {
      await _store.react(emoji);
    } on ContestFailure catch (failure) {
      _tell(failure);
    }
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    try {
      await _store.comment(text);
    } on ContestFailure catch (failure) {
      if (mounted) _input.text = text;
      _tell(failure);
    }
  }

  Future<void> _save() async {
    final ok = await widget.exporter.save(_store.entry);
    if (!mounted) return;
    showNeoSnack(
      context,
      ok ? AppLocalizations.of(context).entrySavedSnack : AppLocalizations.of(context).entrySaveFailed,
    );
  }

  Future<void> _share() async {
    final entry = _store.entry;
    final ok = await widget.exporter.share(
      entry,
      text: AppLocalizations.of(context).entryShareText(entry.groupName),
    );
    if (!mounted || ok) return;
    showNeoSnack(context, AppLocalizations.of(context).entryShareFailed);
  }

  ReportReasonKind _kind(ReportReason reason) =>
      ReportReasonKind.values.byName(reason.name);

  Future<void> _reportEntry() async {
    final draft = await showReportSheet(context);
    if (draft == null || !mounted) return;
    try {
      await _store.reportEntry(_kind(draft.reason), details: draft.details);
      if (!mounted) return;
      showNeoSnack(context, AppLocalizations.of(context).reportSent);
    } on ContestFailure catch (failure) {
      _tell(failure);
    }
  }

  Future<void> _reportComment(EntryComment comment) async {
    final draft = await showReportSheet(context);
    if (draft == null || !mounted) return;
    try {
      await _store.reportComment(
        comment,
        _kind(draft.reason),
        details: draft.details,
      );
      if (!mounted) return;
      showNeoSnack(context, AppLocalizations.of(context).reportSent);
    } on ContestFailure catch (failure) {
      _tell(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<GalleryEntry>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_store.entry);
      },
      child: Scaffold(
        backgroundColor: NeoColors.paper,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) => Column(
              children: [
                _header(context),
                Expanded(child: _content(context)),
                if (_store.canComment) _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final entry = _store.entry;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          NeoIconButton(
            icon: Icons.arrow_back,
            tooltip: AppLocalizations.of(context).backTooltip,
            onPressed: () => Navigator.of(context).pop(_store.entry),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NeoFont.display,
                    color: NeoColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).entryHeader(
                    entry.seq,
                    formatMoment(context, entry.submittedAt),
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
          if (!entry.mine)
            NeoIconButton(
              icon: Icons.flag_outlined,
              tooltip: AppLocalizations.of(context).reportEntryTooltip,
              onPressed: _reportEntry,
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final entry = _store.entry;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F2E9),
                border: Border.all(color: const Color(0xFF17110E), width: 8),
                boxShadow: const [
                  BoxShadow(
                    color: NeoColors.ink,
                    offset: Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: PixelArt(
                width: entry.width,
                height: entry.height,
                palette: entry.palette,
                pixels: entry.pixels,
                semanticLabel: AppLocalizations.of(
                  context,
                ).entryArtSemantics(entry.groupName, entry.seq),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NeoButton(
                label: AppLocalizations.of(context).entrySavePhoto,
                icon: Icons.download_outlined,
                variant: NeoButtonVariant.outline,
                expand: true,
                onPressed: _save,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NeoButton(
                label: AppLocalizations.of(context).postMenuShare,
                icon: Icons.ios_share,
                variant: NeoButtonVariant.outline,
                expand: true,
                onPressed: _share,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (entry.rank != null) _rankCard(entry),
        _ratingCard(),
        const SizedBox(height: 12),
        _reactionsRow(),
        const SizedBox(height: 18),
        Text(
          _store.isLoaded
              ? AppLocalizations.of(
                  context,
                ).commentsTitleCount(_store.comments.length)
              : AppLocalizations.of(context).commentsTitle,
          style: const TextStyle(
            color: NeoColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (!_store.isLoaded)
          _store.error == null
              ? const Center(
                  child: CircularProgressIndicator(color: NeoColors.ink),
                )
              : Column(
                  children: [
                    Text(
                      contestFailureText(
                        AppLocalizations.of(context),
                        _store.error!,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NeoButton(
                      label: AppLocalizations.of(context).retry,
                      onPressed: _store.load,
                    ),
                  ],
                )
        else if (_store.comments.isEmpty)
          Text(
            AppLocalizations.of(context).noComments,
            style: const TextStyle(
              color: NeoColors.muted,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          for (final comment in _store.comments) _commentTile(comment),
      ],
    );
  }

  Widget _rankCard(GalleryEntry entry) {
    final l10n = AppLocalizations.of(context);
    final medals = {1: l10n.rank1, 2: l10n.rank2, 3: l10n.rank3};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: NeoTheme.panel(color: NeoColors.yellow),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.rankScoreLine(
                medals[entry.rank] ?? l10n.rankTop3,
                entry.score?.toStringAsFixed(2) ?? '?',
                entry.voteCount ?? 0,
              ),
              style: const TextStyle(
                color: NeoColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingCard() {
    final entry = _store.entry;
    final detail = _store.detail;
    final canRate = _store.canRate;
    final l10n = AppLocalizations.of(context);
    String note;
    if (detail == null) {
      note = l10n.ratingLoading;
    } else if (entry.mine) {
      note = l10n.ratingOwnGroup;
    } else if (!detail.participant) {
      note = l10n.ratingNotParticipant;
    } else if (detail.phase != ContestPhase.judging) {
      note = detail.phase == ContestPhase.finalized
          ? l10n.ratingContestOver
          : l10n.ratingNotYet;
    } else {
      note = entry.myScore == null
          ? l10n.ratingTapStar
          : l10n.ratingYouGave(entry.myScore!);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NeoTheme.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                Semantics(
                  button: canRate,
                  label: l10n.rateStars(star),
                  child: IconButton(
                    tooltip: l10n.rateStars(star),
                    onPressed: canRate ? () => _rate(star) : null,
                    icon: Icon(
                      (entry.myScore ?? 0) >= star
                          ? Icons.star
                          : Icons.star_border,
                      size: 34,
                      color: (entry.myScore ?? 0) >= star
                          ? NeoColors.orange
                          : NeoColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            note,
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionsRow() {
    final mine = _store.entry.myEmoji;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final emoji in _reactions)
          GestureDetector(
            onTap: _store.canComment ? () => _react(emoji) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mine == emoji ? NeoColors.yellow : NeoColors.surface,
                border: Border.all(color: NeoColors.ink, width: 2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$emoji ${_store.reactions[emoji] ?? 0}',
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _commentTile(EntryComment comment) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: NeoTheme.panel(
      color: comment.mine ? NeoColors.yellow : NeoColors.surface,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.mine
                    ? AppLocalizations.of(context).commentYou
                    : comment.authorName,
                style: const TextStyle(
                  color: NeoColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                comment.body,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!comment.mine)
          IconButton(
            tooltip: AppLocalizations.of(context).reportCommentTooltip,
            onPressed: () => _reportComment(comment),
            icon: const Icon(Icons.flag_outlined, size: 20),
          ),
      ],
    ),
  );

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    color: NeoColors.surface,
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            maxLength: 200,
            minLines: 1,
            maxLines: 2,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              counterText: '',
              hintText: AppLocalizations.of(context).writeCommentHint,
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        NeoIconButton(
          icon: Icons.send,
          tooltip: AppLocalizations.of(context).sendTooltip,
          fill: NeoColors.yellow,
          onPressed: _store.sending ? null : _send,
        ),
      ],
    ),
  );
}
