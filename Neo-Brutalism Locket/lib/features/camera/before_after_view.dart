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
  });

  final Widget after;
  final Widget? before;

  /// Names shown in the top corners while that side is visible (null: none).
  final String? beforeLabel;
  final String? afterLabel;

  /// "Drag to compare" until the first drag.
  final bool showHint;

  @override
  State<RevealCompare> createState() => _RevealCompareState();
}

class _RevealCompareState extends State<RevealCompare> {
  /// Share of the width, from the left, that shows the "before" side.
  double _split = 0;
  bool _dragged = false;

  void _moveTo(double dx, double width) {
    if (width <= 0) return;
    setState(() => _split = (dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final before = widget.before;
    if (before == null) return widget.after;
    return TabSwipeExclusion(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final x = _split * width;
          // The round handle stays on the picture even when the divider is at
          // an edge.
          final handleX = x.clamp(22.0, width - 22.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              Haptics.light();
              _dragged = true;
              _moveTo(details.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (details) =>
                _moveTo(details.localPosition.dx, width),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.after,
                ClipRect(
                  clipper: _LeftOf(x),
                  child: SizedBox.expand(child: before),
                ),
                Positioned(
                  left: x.clamp(1.5, width - 1.5) - 1.5,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NeoColors.ink,
                        boxShadow: [
                          BoxShadow(color: NeoColors.surface, spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: handleX - 20,
                  top: 0,
                  bottom: 0,
                  width: 40,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: NeoColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: NeoColors.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: NeoColors.ink,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 22,
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
                        color: NeoColors.green,
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
                          color: NeoColors.green,
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
