import 'package:neo_brutalism_locket/app/tab_swipe_detector.dart';
import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/style_art.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_working_label.dart';

/// The style picker under the photo: a strip of pills (NO STYLE, 8-BIT, VAN
/// GOGH), the current one big in the middle and its neighbours smaller on
/// either side, so the next style's name shows before you reach it. Swipe the
/// strip, or tap a neighbour, to move; each pill has its own background.
/// Tapping the current one does nothing, so it is never switched by accident.
class StylePill extends StatefulWidget {
  const StylePill({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final StyleType value;
  final ValueChanged<StyleType> onChanged;
  final bool enabled;

  @override
  State<StylePill> createState() => _StylePillState();
}

class _StylePillState extends State<StylePill> {
  static const height = 56.0;

  static const _currentSize = Size(128, 46);
  static const _sideSize = Size(88, 34);

  /// Distance between the centres of the current pill and a neighbour.
  static const _spacing = 104.0;

  /// Drag distance (px) or fling speed (px/s) that counts as a swipe.
  static const _swipeDistance = 24.0;
  static const _swipeVelocity = 300.0;

  double _drag = 0;

  bool get _hasNext => widget.value.index < StyleType.values.length - 1;
  bool get _hasPrevious => widget.value.index > 0;

  void _move(int delta) {
    final index = widget.value.index + delta;
    if (index < 0 || index >= StyleType.values.length) return;
    Haptics.select();
    widget.onChanged(StyleType.values[index]);
  }

  void _endDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final drag = _drag;
    setState(() => _drag = 0);
    if (drag <= -_swipeDistance || velocity <= -_swipeVelocity) {
      _move(1); // finger moved left: next mode
    } else if (drag >= _swipeDistance || velocity >= _swipeVelocity) {
      _move(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.value;
    final values = StyleType.values;
    final l10n = AppLocalizations.of(context);
    return TabSwipeExclusion(
      child: Semantics(
        slider: true,
        label: l10n.styleSliderSemantics,
        value: styleName(l10n, style),
        increasedValue: styleName(
          l10n,
          _hasNext ? values[style.index + 1] : style,
        ),
        decreasedValue: styleName(
          l10n,
          _hasPrevious ? values[style.index - 1] : style,
        ),
        onIncrease: widget.enabled && _hasNext ? () => _move(1) : null,
        onDecrease: widget.enabled && _hasPrevious ? () => _move(-1) : null,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: widget.enabled
                ? (details) => setState(
                    () => _drag = (_drag + details.delta.dx).clamp(-60.0, 60.0),
                  )
                : null,
            onHorizontalDragEnd: widget.enabled ? _endDrag : null,
            onHorizontalDragCancel: widget.enabled
                ? () => setState(() => _drag = 0)
                : null,
            child: SizedBox(
              height: height,
              child: ClipRect(
                // Room for the hard shadows inside the clip.
                clipBehavior: Clip.hardEdge,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final centre = constraints.maxWidth / 2;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final item in values)
                          _item(item, centre: centre, current: style),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    StyleType item, {
    required double centre,
    required StyleType current,
  }) {
    final l10n = AppLocalizations.of(context);
    final offset = item.index - current.index;
    final isCurrent = offset == 0;
    final size = isCurrent ? _currentSize : _sideSize;
    // Only the current pill and its two neighbours are shown.
    final shown = offset.abs() <= 1;
    final shift = _drag * 0.5;
    return AnimatedPositioned(
      key: ValueKey(item),
      duration: _drag == 0 ? const Duration(milliseconds: 180) : Duration.zero,
      curve: Curves.easeOut,
      left: centre + offset * _spacing + shift - size.width / 2,
      top: (height - size.height) / 2 - 2,
      width: size.width,
      height: size.height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: !shown
            ? 0
            : isCurrent
            ? 1
            : 0.7,
        child: IgnorePointer(
          ignoring: !shown,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled && !isCurrent && shown
                ? () => _move(offset)
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size.height / 2),
                border: Border.all(color: NeoColors.ink, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: NeoColors.ink,
                    offset: isCurrent ? const Offset(3, 3) : const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: NeoPanelClip(
                radius: size.height / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StyleArt(style: item, veil: isCurrent ? 0.82 : 0.7),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                styleName(l10n, item),
                                maxLines: 1,
                                style: TextStyle(
                                  color: NeoColors.ink,
                                  fontSize: isCurrent ? 12 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final dot in StyleType.values)
                                      Container(
                                        width: dot == item ? 12 : 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: dot == item
                                              ? NeoColors.ink
                                              : NeoColors.ink.withValues(
                                                  alpha: 0.3,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
