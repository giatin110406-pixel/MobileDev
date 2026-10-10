import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Enter a group's canvas in the contest. Shows what will be sent (a snapshot
/// taken now by the server), how many places are left, and asks to confirm.
Future<void> showSubmitEntrySheet(
  BuildContext context, {
  required ContestStore store,
  required OwnedGroup group,
  required CanvasRepository canvases,
  ValueChanged<int>? onSubmitted,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => _SubmitSheet(
    store: store,
    group: group,
    canvases: canvases,
    onSubmitted: onSubmitted,
  ),
);

class _SubmitSheet extends StatefulWidget {
  const _SubmitSheet({
    required this.store,
    required this.group,
    required this.canvases,
    this.onSubmitted,
  });

  final ContestStore store;
  final OwnedGroup group;
  final CanvasRepository canvases;
  final ValueChanged<int>? onSubmitted;

  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  CanvasData? _preview;
  bool _previewFailed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final id = await widget.canvases.activeCanvasId(widget.group.id);
      if (id == null) {
        if (mounted) setState(() => _previewFailed = true);
        return;
      }
      final data = await widget.canvases.load(id);
      if (mounted) setState(() => _preview = data);
    } on CanvasFailure {
      if (mounted) setState(() => _previewFailed = true);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final seq = await widget.store.submit(widget.group);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted?.call(seq);
    } on ContestFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = contestFailureText(AppLocalizations.of(context), failure);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(18),
      decoration: NeoTheme.panel(radius: 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(
                  context,
                ).submitSheetTitle(widget.group.name),
                style: const TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: NeoColors.ink, width: 2),
                    ),
                    child: preview != null
                        ? PixelArt(
                            width: preview.width,
                            height: preview.height,
                            palette: preview.palette,
                            pixels: preview.pixels,
                            semanticLabel: AppLocalizations.of(
                              context,
                            ).canvasWillBeSubmitted,
                          )
                        : AspectRatio(
                            aspectRatio: 1,
                            child: Center(
                              child: _previewFailed
                                  ? Text(AppLocalizations.of(context).noPreview)
                                  : const CircularProgressIndicator(
                                      color: NeoColors.ink,
                                    ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  final contest = widget.store.contest;
                  if (contest == null) return const SizedBox.shrink();
                  final left = contest.maxEntries - contest.acceptedCount;
                  return Text(
                    left > 0
                        ? AppLocalizations.of(context).submitSpotsLeft(
                            contest.acceptedCount,
                            contest.maxEntries,
                          )
                        : AppLocalizations.of(
                            context,
                          ).submitGalleryFull(contest.maxEntries),
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).submitSnapshotNote,
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: NeoColors.pink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              NeoButton(
                label: _busy
                    ? AppLocalizations.of(context).submitting
                    : AppLocalizations.of(context).contestSubmitButton,
                icon: Icons.upload_outlined,
                expand: true,
                onPressed: _busy || preview == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
