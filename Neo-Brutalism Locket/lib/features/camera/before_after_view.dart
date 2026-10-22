import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/app/tab_swipe_detector.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Before and after on one picture. Put a finger down and drag: everything left of
/// the finger shows [before], everything right of it shows [after], with a handle
/// on the dividing line. Lifting the finger leaves the divider where it is.
///
/// It starts with [after] all over (the finished picture); with no [before] there
/// is nothing to compare and [after] is all there is.
class RevealCompare extends StatefulWidget {
  const RevealCompare({
    super.key,
    required this.after,
    this.before,
    this.beforeLabel,
    this.afterLabel,
    this.showHint = false,
    this.beforeDelay = Duration.zero,
  });

  final Widget after;
  final Widget? before;

  /// Names shown in the top corners while that side is visible (null: none).
  final String? beforeLabel;
  final String? afterLabel;

  /// "Drag to compare" until the first drag.
  final bool showHint;

  /// How long to wait before the "before" picture is put on screen (and starts
  /// loading, if it comes over the network): the finished picture should get
  /// the connection first. A drag starts it at once.
  final Duration beforeDelay;

  @override
  State<RevealCompare> createState() => _RevealCompareState();
}

/// Once anyone has dragged a picture the little grip no longer sits on every
/// picture to point it out.
bool _learnedToDrag = false;

class _RevealCompareState extends State<RevealCompare> {
  /// Share of the width, from the left, that shows the "before" side.
  double _split = 0;
  bool _dragged = false;

  /// A finger is down: the handle shrinks and fades so the picture shows.
  bool _dragging = false;

  /// Where the handle sits on the line, as a share of the height. It rides with
  /// the finger and rests low, away from the middle of the picture.
  double _knobY = 0.74;

  /// The line and grip show while dragging and for a moment after; then they
  /// fade so nothing sits on the picture.
  bool _chrome = false;
  Timer? _hideTimer;

  /// The "before" picture is only built (so only loaded) from here on.
  bool _beforeReady = false;
  Timer? _beforeTimer;

  @override
  void initState() {
    super.initState();
    if (widget.beforeDelay == Duration.zero) {
      _beforeReady = true;
    } else {
      _beforeTimer = Timer(widget.beforeDelay, () {
        if (mounted) setState(() => _beforeReady = true);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _beforeTimer?.cancel();
    super.dispose();
  }

  void _showChrome({required bool keep}) {
    _hideTimer?.cancel();
    _chrome = true;
    if (!keep) {
      _hideTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _chrome = false);
      });
    }
  }

  void _moveTo(Offset at, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    setState(() {
      _split = (at.dx / size.width).clamp(0.0, 1.0);
      _knobY = (at.dy / size.height).clamp(0.12, 0.88);
    });
  }

  @override
  Widget build(BuildContext context) {
    final before = widget.before;
    if (before == null) return widget.after;
    return TabSwipeExclusion(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final size = box.biggest;
          final x = _split * width;
          // The handle stays on the picture even when the divider is at an edge.
          final handleX = x.clamp(14.0, width - 14.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              Haptics.light();
              _dragged = true;
              _learnedToDrag = true;
              _dragging = true;
              _beforeReady = true;
              _showChrome(keep: true);
              _moveTo(details.localPosition, size);
            },
            onHorizontalDragUpdate: (details) =>
                _moveTo(details.localPosition, size),
            onHorizontalDragEnd: (_) => setState(() {
              _dragging = false;
              _showChrome(keep: false);
            }),
            onHorizontalDragCancel: () => setState(() {
              _dragging = false;
              _showChrome(keep: false);
            }),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.after,
                if (_beforeReady)
                  ClipRect(
                    clipper: _LeftOf(x),
                    child: SizedBox.expand(child: before),
                  ),
                // The dividing line: hairline-thin, with a light edge so it reads on
                // dark and bright pictures alike. Only while dragging.
                Positioned(
                  left: x.clamp(1.0, width - 1.0) - 0.75,
                  top: 0,
                  bottom: 0,
                  width: 1.5,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _chrome ? 0.85 : 0,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: NeoColors.ink,
                          boxShadow: [
                            BoxShadow(
                              color: NeoColors.surface,
                              spreadRadius: 0.75,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // A tiny grip: faint on a picture nobody has dragged yet, then
                // only while a finger is on it.
                Positioned(
                  left: handleX - 11,
                  top: _knobY * size.height - 11,
                  width: 22,
                  height: 22,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _dragging
                          ? 0.4
                          : _chrome
                          ? 0.6
                          : (_learnedToDrag ? 0.0 : 0.5),
                      child: Container(
                        decoration: BoxDecoration(
                          color: NeoColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: NeoColors.ink, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.beforeLabel != null && _split > 0.18)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IgnorePointer(
                      child: NeoLabel(
                        widget.beforeLabel!,
                        color: NeoColors.surface,
                      ),
                    ),
                  ),
                if (widget.afterLabel != null && _split < 0.82)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: NeoLabel(
                        widget.afterLabel!,
                        color: NeoColors.accent,
                      ),
                    ),
                  ),
                if (widget.showHint && !_dragged)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: NeoLabel(
                          AppLocalizations.of(context).dragToCompare,
                          color: NeoColors.accent,
                          icon: Icons.touch_app_outlined,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeftOf extends CustomClipper<Rect> {
  const _LeftOf(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _LeftOf old) => old.x != x;
}

/// A shot on this phone before and after its style (see [RevealCompare]). Until the
/// style is ready only the original shows.
class BeforeAfterView extends StatelessWidget {
  const BeforeAfterView({
    super.key,
    required this.originalPath,
    required this.styledPath,
    required this.styleLabel,
  });

  final String originalPath;

  /// Null while the style is being applied (or when there is none).
  final String? styledPath;

  /// The style's name, shown on the styled side (`8-BIT`, `VAN GOGH`).
  final String styleLabel;

  Widget _picture(BuildContext context, String path) => Image.file(
    File(path),
    key: ValueKey(path),
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Center(
      child: Text(
        AppLocalizations.of(context).imageNotFound,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final styled = styledPath;
    // Dragging on a picture never swipes the menu tabs, styled or not.
    if (styled == null) {
      return TabSwipeExclusion(child: _picture(context, originalPath));
    }
    return RevealCompare(
      before: _picture(context, originalPath),
      after: _picture(context, styled),
      beforeLabel: AppLocalizations.of(context).originalLabel,
      afterLabel: styleLabel,
      showHint: true,
    );
  }
}
