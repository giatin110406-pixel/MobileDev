import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_view.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/features/contest/hall_of_fame_screen.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_store.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// The Gallery Room: a long exhibition corridor with the entries framed on both
/// walls. Walk down it, tap a picture to look closer, rate and comment. A grid
/// view of the same entries is one tap away (and is what screen readers use).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    required this.repository,
    required this.title,
    this.contestId,
    this.safety,
    super.key,
  });

  final ContestRepository repository;
  final String title;

  /// Null = this week's contest.
  final String? contestId;
  final SafetyRepository? safety;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final GalleryStore _store = GalleryStore(
    widget.repository,
    contestId: widget.contestId,
  );
  final EntryImageCache _cache = EntryImageCache();
  bool _grid = false;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    _cache.dispose();
    super.dispose();
  }

  Future<void> _open(GalleryEntry entry) async {
    final updated = await Navigator.of(context).push<GalleryEntry>(
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(
          repository: widget.repository,
          entry: entry,
          safety: widget.safety,
        ),
      ),
    );
    if (updated != null) _store.replace(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2328),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: NeoColors.paper,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back,
                    tooltip: AppLocalizations.of(context).backTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).galleryRoomTitle,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: NeoFont.display,
                            color: NeoColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NeoIconButton(
                    icon: Icons.emoji_events_outlined,
                    tooltip: AppLocalizations.of(context).hallOfFameTitle,
                    fill: NeoColors.orange,
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => HallOfFameScreen(
                          repository: widget.repository,
                          safety: widget.safety,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeoIconButton(
                    icon: _grid ? Icons.museum_outlined : Icons.grid_view,
                    tooltip: _grid
                        ? AppLocalizations.of(context).galleryViewCorridor
                        : AppLocalizations.of(context).galleryViewGrid,
                    fill: NeoColors.yellow,
                    onPressed: () => setState(() => _grid = !_grid),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _store,
                builder: (context, _) => _body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!_store.isLoaded) {
      return Center(
        child: _store.error == null
            ? const CircularProgressIndicator(color: NeoColors.paper)
            : _Notice(
                text: contestFailureText(
                  AppLocalizations.of(context),
                  _store.error!,
                ),
                actionLabel: AppLocalizations.of(context).retry,
                onAction: _store.load,
              ),
      );
    }
    final empty = _store.entries.isEmpty;
    return Stack(
      children: [
        if (_grid && empty)
          Center(
            child: _Notice(text: AppLocalizations.of(context).galleryEmpty),
          )
        else if (_grid)
          GalleryGrid(entries: _store.entries, onOpen: _open)
        else
          CorridorView(
            entries: _store.entries,
            cache: _cache,
            onOpen: _open,
            onNearEnd: _store.hasMore ? _store.loadMore : null,
          ),
        // With no entry yet the corridor is still there, with blank canvases on
        // every wall; a note says what will happen.
        if (empty && !_grid)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: NeoTheme.panel(color: NeoColors.surface),
                child: Text(
                  AppLocalizations.of(context).galleryEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        if (_store.error != null)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: NeoTheme.panel(color: NeoColors.orange),
              child: Text(
                AppLocalizations.of(context).galleryLoadMoreFailed,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeoColors.paper,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            NeoButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// The same entries as a grid of framed pictures.
class GalleryGrid extends StatelessWidget {
  const GalleryGrid({required this.entries, required this.onOpen, super.key});

  final List<GalleryEntry> entries;
  final ValueChanged<GalleryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Semantics(
          button: true,
          label: AppLocalizations.of(
            context,
          ).galleryEntrySemantics(entry.seq, entry.groupName),
          child: GestureDetector(
            onTap: Haptics.tap(() => onOpen(entry)),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CorridorFrameColors.mat,
                border: Border.all(color: CorridorFrameColors.frame, width: 5),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: PixelArt(
                        width: entry.width,
                        height: entry.height,
                        palette: entry.palette,
                        pixels: entry.pixels,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${entry.seq} · ${entry.groupName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
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

/// The colours of the frames in the grid view (the same as in the corridor).
abstract final class CorridorFrameColors {
  static const frame = Color(0xFF1A1A1A);
  static const mat = Color(0xFFFDF2E9);
}
