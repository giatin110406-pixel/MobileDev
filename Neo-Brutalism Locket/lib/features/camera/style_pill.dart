import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// Background colour of the pill for each mode.
Color stylePillColor(StyleType style) => switch (style) {
  StyleType.none => NeoColors.teal,
  StyleType.pixel8bit => NeoColors.yellow,
  StyleType.vanGogh => NeoColors.blue,
};

/// One small pill under the photo showing the current mode. Swipe it left for
/// the next mode (NO STYLE -> 8-BIT -> VAN GOGH) and right to go back; each mode
/// has its own background colour. Taps do nothing, so it is never switched by
/// accident.
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
  static const width = 184.0;
  static const height = 44.0;

  /// Drag distance (px) or fling speed (px/s) that counts as a swipe.
  static const _swipeDistance = 24.0;
  static const _swipeVelocity = 300.0;

  double _drag = 0;

  /// +1 when the last change moved forward, -1 backward (slide direction).
  int _direction = 1;

  bool get _hasNext => widget.value.index < StyleType.values.length - 1;
  bool get _hasPrevious => widget.value.index > 0;

  void _step(int delta) {
    final index = widget.value.index + delta;
    if (index < 0 || index >= StyleType.values.length) return;
    Haptics.select();
    setState(() => _direction = delta);
    widget.onChanged(StyleType.values[index]);
  }

  void _endDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final drag = _drag;
    setState(() => _drag = 0);
    if (drag <= -_swipeDistance || velocity <= -_swipeVelocity) {
      _step(1); // finger moved left: next mode
    } else if (drag >= _swipeDistance || velocity >= _swipeVelocity) {
      _step(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.value;
    final values = StyleType.values;
    return Semantics(
      slider: true,
      label: AppLocalizations.of(context).styleSliderSemantics,
      value: style.label,
      increasedValue: _hasNext ? values[style.index + 1].label : style.label,
      decreasedValue: _hasPrevious
          ? values[style.index - 1].label
          : style.label,
      onIncrease: widget.enabled && _hasNext ? () => _step(1) : null,
      onDecrease: widget.enabled && _hasPrevious ? () => _step(-1) : null,
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: stylePillColor(style),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: NeoColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                _chevron(Icons.chevron_left, visible: _hasPrevious),
                Expanded(
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(_drag * 0.5, 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(style);
                          final from = incoming ? _direction * 0.6 : 0.0;
                          return SlideTransition(
                            position: Tween(
                              begin: Offset(from, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          key: ValueKey(style),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              style.label,
                              maxLines: 1,
                              style: const TextStyle(
                                color: NeoColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final dot in values)
                                  Container(
                                    width: dot == style ? 12 : 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dot == style
                                          ? NeoColors.ink
                                          : NeoColors.ink.withValues(
                                              alpha: 0.3,
                                            ),
                                      borderRadius: BorderRadius.circular(3),
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
                _chevron(Icons.chevron_right, visible: _hasNext),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chevron(IconData icon, {required bool visible}) => SizedBox(
    width: 26,
    child: Icon(
      icon,
      size: 18,
      color: visible ? NeoColors.ink : Colors.transparent,
    ),
  );
}
