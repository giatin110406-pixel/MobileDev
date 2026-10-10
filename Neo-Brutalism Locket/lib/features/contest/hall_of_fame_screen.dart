import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/language.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/features/contest/hall_store.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The colour of a winner's pedestal: yellow, blue and orange for first, second
/// and third.
Color hallFrameColor(int? rank) => switch (rank) {
  1 => const Color(0xFFFFE66D),
  2 => const Color(0xFF45B7D1),
  _ => const Color(0xFFF7A072),
};

/// The Hall of Fame: a podium with the three winners of a week, first place in
/// the middle. The arrows go to earlier weeks. The podium is there even when
/// nobody has won yet.
class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({required this.repository, this.safety, super.key});

  final ContestRepository repository;
  final SafetyRepository? safety;

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  late final HallStore _store = HallStore(widget.repository);

  /// Which week is on the podium: 0 is the newest.
  int _week = 0;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
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

  /// The weeks that have winners, newest first.
  List<String> get _weeks {
    final keys = <String>[];
    for (final entry in _store.entries) {
      final key = entry.weekKey ?? '';
      if (!keys.contains(key)) keys.add(key);
    }
    return keys;
  }

  void _earlier(List<String> weeks) {
    if (_week + 1 < weeks.length) {
      setState(() => _week++);
    }
    // Close to the oldest week loaded: fetch the next page.
    if (_week + 2 >= weeks.length && _store.hasMore) _store.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back,
                    tooltip: l10n.backTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.galleryRoomTitle,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.hallOfFameTitle,
                          style: const TextStyle(
                            color: NeoColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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
    final l10n = AppLocalizations.of(context);
    if (!_store.isLoaded) {
      return Center(
        child: _store.error == null
            ? const CircularProgressIndicator(color: NeoColors.ink)
            : _Notice(
                text: contestFailureText(l10n, _store.error!),
                actionLabel: l10n.retry,
                onAction: _store.load,
              ),
      );
    }
    final weeks = _weeks;
    final week = weeks.isEmpty ? null : weeks[_week.clamp(0, weeks.length - 1)];
    final winners = <int, GalleryEntry>{
      for (final entry in _store.entries)
        if ((entry.weekKey ?? '') == week && entry.rank != null)
          entry.rank!: entry,
    };
    final sample = winners.values.isEmpty ? null : winners.values.first;
    final vi = isVietnamese(context);
    final theme = sample == null
        ? null
        : (vi ? sample.titleVi : sample.titleEn);
    final weekName = week == null ? '' : week.split('-').last;
    final index = weeks.isEmpty ? 0 : _week.clamp(0, weeks.length - 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              NeoIconButton(
                icon: Icons.chevron_left,
                tooltip: l10n.hallEarlierWeek,
                onPressed: index + 1 < weeks.length
                    ? () => _earlier(weeks)
                    : null,
              ),
              Expanded(
                child: Text(
                  weeks.isEmpty
                      ? l10n.hallOfFameTitle
                      : [
                          weekName,
                          if (theme != null && theme.isNotEmpty) theme,
                        ].join(' · '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontFamily: NeoFont.display,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              NeoIconButton(
                icon: Icons.chevron_right,
                tooltip: l10n.hallLaterWeek,
                onPressed: index > 0
                    ? () => setState(() => _week = index - 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            container: true,
            label: l10n.hallPodiumSemantics(weekName),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
              decoration: NeoTheme.panel(color: NeoColors.purple),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final rank in const [2, 1, 3]) ...[
                    if (rank != 2) const SizedBox(width: 8),
                    Expanded(
                      child: _Place(
                        rank: rank,
                        entry: winners[rank],
                        onOpen: _open,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (weeks.isEmpty) ...[
            const SizedBox(height: 22),
            _Notice(text: l10n.hallEmpty),
          ],
        ],
      ),
    );
  }
}

/// One place on the podium: the painting (or a question mark), the group's name
/// and the pedestal with its number.
class _Place extends StatelessWidget {
  const _Place({required this.rank, required this.entry, required this.onOpen});

  final int rank;
  final GalleryEntry? entry;
  final ValueChanged<GalleryEntry> onOpen;

  static double heightOf(int rank) => switch (rank) {
    1 => 150,
    2 => 108,
    _ => 76,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final won = entry;
    final colour = hallFrameColor(rank);
    final picture = AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: NeoTheme.panel(
          color: NeoColors.surface,
          borderWidth: 3,
          radius: 4,
        ),
        child: won == null
            ? const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: NeoColors.muted,
                    fontFamily: NeoFont.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : PixelArt(
                width: won.width,
                height: won.height,
                palette: won.palette,
                pixels: won.pixels,
                semanticLabel: won.groupName,
              ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        won == null
            ? Semantics(label: l10n.hallNoWinner, child: picture)
            : Semantics(
                button: true,
                label: l10n.galleryEntrySemantics(won.seq, won.groupName),
                child: GestureDetector(
                  onTap: Haptics.tap(() => onOpen(won)),
                  child: picture,
                ),
              ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: Text(
            won?.groupName ?? l10n.hallNoWinner,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: won == null ? NeoColors.ink.withAlpha(150) : NeoColors.ink,
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (won?.score != null)
          Text(
            '★ ${won!.score!.toStringAsFixed(2)}',
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        const SizedBox(height: 6),
        _Pedestal(rank: rank, colour: colour, height: heightOf(rank)),
      ],
    );
  }
}

/// A column like the ones on a real podium: a cap, a fluted shaft with the
/// number on it, and a base. Flat colours, black outlines.
class _Pedestal extends StatelessWidget {
  const _Pedestal({
    required this.rank,
    required this.colour,
    required this.height,
  });

  final int rank;
  final Color colour;
  final double height;

  @override
  Widget build(BuildContext context) {
    const edge = BorderSide(color: NeoColors.ink, width: 3);
    Widget slab(double h) => Container(
      height: h,
      decoration: BoxDecoration(
        color: colour,
        border: Border.all(color: NeoColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slab(14),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: const BoxDecoration(
            color: NeoColors.surface,
            border: Border(left: edge, right: edge),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: _FlutePainter())),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colour,
                  border: Border.all(color: NeoColors.ink, width: 3),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontFamily: NeoFont.display,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        slab(14),
      ],
    );
  }
}

/// The grooves down the shaft of a column.
class _FlutePainter extends CustomPainter {
  const _FlutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NeoColors.ink.withAlpha(60)
      ..strokeWidth = 2;
    const grooves = 5;
    for (var i = 1; i < grooves; i++) {
      final x = size.width * i / grooves;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlutePainter old) => false;
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
              color: NeoColors.ink,
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
