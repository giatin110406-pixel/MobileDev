import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/language.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/entry_detail_screen.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/features/contest/hall_stage.dart';
import 'package:neo_brutalism_locket/features/contest/hall_store.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The colour of a winner's number plate: gold, off-white and coral for first,
/// second and third.
Color hallFrameColor(int? rank) => switch (rank) {
  1 => const Color(0xFFF5D06F),
  2 => const Color(0xFFF8EED2),
  _ => const Color(0xFFFF6F61),
};

/// The Hall of Fame: an opera stage. The curtains part and the three winners of a
/// week stand on columns that are built brick by brick, first place in the middle.
/// The arrows go to earlier weeks. The stage is there even when nobody has won yet.
///
/// A swipe down goes back to the Gallery: [onBack] is what that does (it pops the
/// route when null).
class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({
    required this.repository,
    this.safety,
    this.onBack,
    super.key,
  });

  final ContestRepository repository;
  final SafetyRepository? safety;
  final VoidCallback? onBack;

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen>
    with SingleTickerProviderStateMixin {
  late final HallStore _store = HallStore(widget.repository);
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );
  bool _started = false;

  /// Which week is on the stage: 0 is the newest.
  int _week = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_begin);
    _store.load();
  }

  /// The curtains open once there is something to show behind them.
  void _begin() {
    if (_started || !_store.isLoaded || !mounted) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _store.removeListener(_begin);
    _store.dispose();
    _intro.dispose();
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

  /// How far the stage has been pulled down by a finger, on the way out.
  double _pulled = 0;

  void _leave() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _drag(DragUpdateDetails details) {
    setState(() => _pulled = (_pulled + details.delta.dy).clamp(0.0, 600.0));
  }

  /// A swipe down, or a drag far enough, goes back to the Gallery.
  void _release(DragEndDetails details) {
    final far = _pulled > 120 || details.velocity.pixelsPerSecond.dy > 900;
    if (far) {
      _leave();
    }
    setState(() => _pulled = 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0809),
      body: Semantics(
        onDismiss: _leave,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: _drag,
          onVerticalDragEnd: _release,
          onVerticalDragCancel: () => setState(() => _pulled = 0),
          child: Transform.translate(
            offset: Offset(0, _pulled),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: _store,
                  builder: (context, _) => _body(context),
                ),
                // The name of the room, on a yellow panel under the valance so it
                // can be read over the curtains.
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(top: height * 0.07),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _Plate(
                        color: NeoColors.accent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.hallOfFameTitle.toUpperCase(),
                              style: const TextStyle(
                                color: NeoColors.ink,
                                fontFamily: NeoFont.display,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: NeoColors.ink,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    l10n.hallSwipeHint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NeoColors.ink,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_store.isLoaded) {
      // The curtains are still shut while the winners load.
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(painter: CurtainPainter(intro: _intro)),
          ),
          Center(
            child: _store.error == null
                ? const CircularProgressIndicator(color: NeoColors.ink)
                : _Plate(
                    child: _Notice(
                      text: contestFailureText(l10n, _store.error!),
                      actionLabel: l10n.retry,
                      onAction: _store.load,
                    ),
                  ),
          ),
        ],
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
    // "2026-W43" is week 43.
    final weekName = week == null ? '' : week.split('W').last;
    final index = weeks.isEmpty ? 0 : _week.clamp(0, weeks.length - 1);

    return Semantics(
      container: true,
      label: l10n.hallPodiumSemantics(weekName),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: StagePainter(intro: _intro)),
          LayoutBuilder(
            builder: (context, box) {
              final layout = StageLayout(box.biggest);
              return AnimatedBuilder(
                animation: _intro,
                builder: (context, _) => Stack(
                  children: [
                    for (final rank in const [2, 1, 3])
                      _Place(
                        layout: layout,
                        rank: rank,
                        entry: winners[rank],
                        shown: StageTiming.plate(_intro.value, rank),
                        onOpen: _open,
                      ),
                  ],
                ),
              );
            },
          ),
          IgnorePointer(
            child: CustomPaint(painter: CurtainPainter(intro: _intro)),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (weeks.isEmpty) ...[
                      _Plate(child: _Notice(text: l10n.hallEmpty)),
                      const SizedBox(height: 10),
                    ],
                    // Which week's winners stand on the stage, and the arrows to the
                    // weeks before it (only when there is more than one week).
                    Row(
                      children: [
                        if (weeks.length > 1)
                          NeoIconButton(
                            icon: Icons.chevron_left,
                            tooltip: l10n.hallEarlierWeek,
                            onPressed: index + 1 < weeks.length
                                ? () => _earlier(weeks)
                                : null,
                          ),
                        Expanded(
                          child: Center(
                            child: _Plate(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    weeks.isEmpty
                                        ? l10n.hallOfFameTitle
                                        : l10n.hallWeekTitle(weekName),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NeoColors.ink,
                                      fontFamily: NeoFont.display,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (theme != null && theme.isNotEmpty)
                                    Text(
                                      theme,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: NeoColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (weeks.length > 1)
                          NeoIconButton(
                            icon: Icons.chevron_right,
                            tooltip: l10n.hallLaterWeek,
                            onPressed: index > 0
                                ? () => setState(() => _week = index - 1)
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A panel like every other in the app (black edge, hard shadow): whatever is
/// written on it can be read over the curtains and the stage.
class _Plate extends StatelessWidget {
  const _Plate({required this.child, this.color = NeoColors.surface});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: NeoTheme.panel(color: color),
      child: child,
    );
  }
}

/// One place on the stage: the painting in its frame and the name plate above the
/// column, and the number on the shaft. They fade in once the column is built.
class _Place extends StatelessWidget {
  const _Place({
    required this.layout,
    required this.rank,
    required this.entry,
    required this.shown,
    required this.onOpen,
  });

  final StageLayout layout;
  final int rank;
  final GalleryEntry? entry;

  /// 0 to 1: how much of the painting and the plate can be seen.
  final double shown;
  final ValueChanged<GalleryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final won = entry;
    final width = layout.capitalWidth * 1.1;
    final left = layout.centerX(rank) - width / 2;
    final h = layout.columnHeight(rank);
    // The frame is the shape of a banner; a painting keeps its own shape inside it.
    final picture = AspectRatio(
      aspectRatio: profileBannerAspect,
      child: Container(
        padding: const EdgeInsets.all(3),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Center(
                child: PixelArt(
                  width: won.width,
                  height: won.height,
                  palette: won.palette,
                  pixels: won.pixels,
                  semanticLabel: won.groupName,
                ),
              ),
      ),
    );

    final plate = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: NeoTheme.panel(color: hallFrameColor(rank), radius: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won?.groupName ?? l10n.hallNoWinner,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: won == null ? NeoColors.ink.withAlpha(150) : NeoColors.ink,
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (won?.score != null)
            Text(
              '★ ${won!.score!.toStringAsFixed(2)}',
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );

    final shaftMiddle = layout.baseY - h * 0.45;
    return Stack(
      children: [
        Positioned(
          left: left,
          width: width,
          bottom: layout.height - (layout.topY(rank) - 8),
          child: Opacity(
            opacity: shown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                won == null
                    ? Semantics(label: l10n.hallNoWinner, child: picture)
                    : Semantics(
                        button: true,
                        label: l10n.galleryEntrySemantics(
                          won.seq,
                          won.groupName,
                        ),
                        child: GestureDetector(
                          onTap: Haptics.tap(() => onOpen(won)),
                          child: picture,
                        ),
                      ),
                const SizedBox(height: 4),
                plate,
              ],
            ),
          ),
        ),
        Positioned(
          left: layout.centerX(rank) - 19,
          top: shaftMiddle - 19,
          width: 38,
          height: 38,
          child: Opacity(
            opacity: shown,
            child: Container(
              alignment: Alignment.center,
              decoration: NeoTheme.panel(
                color: hallFrameColor(rank),
                borderWidth: 3,
                radius: 4,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontFamily: NeoFont.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 12),
          NeoButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}
