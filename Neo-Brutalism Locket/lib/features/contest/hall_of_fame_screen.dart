import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/language.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_view.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/features/contest/gallery_screen.dart';
import 'package:neo_brutalism_locket/features/contest/hall_store.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The wood of a winner's frame: gold, silver or bronze.
Color hallFrameColor(int? rank) => switch (rank) {
  1 => const Color(0xFFFFE66D), // gold
  2 => const Color(0xFF45B7D1), // silver
  _ => const Color(0xFFF7A072), // bronze
};

/// How a winning painting is shown in the Hall of Fame: a metal frame by rank, a
/// spot light, and a brass plate with the group, the week and the theme.
FrameDecor hallDecor(GalleryEntry entry, {required bool vietnamese}) {
  final week = (entry.weekKey ?? '').split('-').last;
  final theme = vietnamese ? entry.titleVi : entry.titleEn;
  return FrameDecor(
    frame: hallFrameColor(entry.rank),
    mat: const Color(0xFFFDF2E9),
    spot: true,
    plaque: [
      entry.groupName,
      [week, theme].where((part) => part != null && part.isNotEmpty).join(': '),
    ],
  );
}

/// The Hall of Fame: a grand room with every winning painting of every week, one
/// bay each, twice the size of the ones in the Gallery, under its own spot light.
class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({required this.repository, this.safety, super.key});

  final ContestRepository repository;
  final SafetyRepository? safety;

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  late final HallStore _store = HallStore(widget.repository);
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

  Future<void> _open(GalleryEntry entry) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EntryDetailScreen(
        repository: widget.repository,
        entry: entry,
        safety: widget.safety,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vi = isVietnamese(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0E1118),
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
                          style: TextStyle(
                            color: NeoColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context).hallOfFameTitle,
                          style: TextStyle(
                            color: NeoColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NeoIconButton(
                    icon: _grid ? Icons.museum_outlined : Icons.grid_view,
                    tooltip: _grid
                        ? AppLocalizations.of(context).hallViewRoom
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
                builder: (context, _) => _body(vi),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(bool vi) {
    if (!_store.isLoaded) {
      return Center(
        child: _store.error == null
            ? const CircularProgressIndicator(color: NeoColors.paper)
            : _Notice(
                text: contestFailureText(AppLocalizations.of(context), _store.error!),
                actionLabel: AppLocalizations.of(context).retry,
                onAction: _store.load,
              ),
      );
    }
    if (_store.entries.isEmpty) {
      return Center(child: _Notice(text: AppLocalizations.of(context).hallEmpty));
    }
    if (_grid) {
      return GalleryGrid(entries: _store.entries, onOpen: _open);
    }
    return CorridorView(
      entries: _store.entries,
      cache: _cache,
      onOpen: _open,
      onNearEnd: _store.hasMore ? _store.loadMore : null,
      layout: (entries) => layoutHall(entries.length),
      style: CorridorStyle.hall,
      decorOf: (entry) => hallDecor(entry, vietnamese: vi),
      label: AppLocalizations.of(context).hallSemantics(_store.entries.length),
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
