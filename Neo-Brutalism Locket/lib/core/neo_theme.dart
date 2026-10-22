import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

abstract final class NeoColors {
  // Sand is the ground; the rest is placed on it:
  //   sand   (60%) - the ground of every screen, and cards, tab bar, sheets
  //   accent (25%) - the yellow: the thing selected or on (selected tab, switch
  //                  and chips, labels, my chat bubbles)
  //   teal   (10%) - the main action: primary buttons
  //   coral        - alerts and unread counts (REC, errors, closed)
  //   lime, peach, purple - extra folder / category tints
  //   black        - outlines, hard shadows and text
  static const ink = Color(0xFF000000);
  static const teal = Color(0xFF84D0C8);
  static const paper = Color(0xFFF8EED2);
  static const surface = Color(0xFFF8EED2);
  static const accent = Color(0xFFF5D06F);
  static const coral = Color(0xFFFF6F61);
  static const lime = Color(0xFFA6D63B);
  static const peach = Color(0xFFFDE5A1);
  static const purple = Color(0xFF7C6CF0);
  static const grey = Color(0xFF8E8E8E);
  static const muted = Color(0xFF5C5C5C);
  static const switchOff = Color(0xFFE9E5DC);
}

/// The two bundled font families: Space Grotesk for headings, numbers, labels
/// and buttons; Public Sans for everything else.
abstract final class NeoFont {
  static const display = 'SpaceGrotesk';
  static const body = 'PublicSans';
}

abstract final class NeoTheme {
  static ThemeData get data => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: NeoColors.paper,
    colorScheme: const ColorScheme.light(
      primary: NeoColors.ink,
      onPrimary: NeoColors.surface,
      secondary: NeoColors.accent,
      onSecondary: NeoColors.ink,
      surface: NeoColors.surface,
      onSurface: NeoColors.ink,
      error: NeoColors.coral,
      onError: NeoColors.ink,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NeoColors.ink,
      selectionColor: NeoColors.accent,
      selectionHandleColor: NeoColors.ink,
    ),
    splashFactory: NoSplash.splashFactory,
    fontFamily: NeoFont.body,
  );

  static BoxDecoration panel({
    Color color = NeoColors.surface,
    double borderWidth = 2,
    double radius = 8,

    /// A pressed panel has lost its hard shadow (see [NeoPress]).
    bool pressed = false,
  }) => BoxDecoration(
    color: color,
    border: Border.all(color: NeoColors.ink, width: borderWidth),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: NeoPress.shadow(pressed),
  );
}

/// The panel's black outline alone, to lay over the picture inside a
/// [NeoPanelClip] as `foregroundDecoration`: the anti-aliased clip edge at the
/// four rounded corners then never shows a light fringe between the picture and
/// the border.
BoxDecoration neoPanelOutline({double radius = 8, double borderWidth = 2}) =>
    BoxDecoration(
      border: Border.all(color: NeoColors.ink, width: borderWidth),
      borderRadius: BorderRadius.circular(radius),
    );

/// Clips [child] to the inside of a [NeoTheme.panel] of the same [radius] and
/// [borderWidth]. Clipping with the panel's own `clipBehavior` cuts at the outer
/// edge, so the child's square corners cover the inner half of the border and
/// the black outline looks chewed at the four corners; this clips at the inner
/// edge instead.
class NeoPanelClip extends StatelessWidget {
  const NeoPanelClip({
    required this.child,
    this.radius = 8,
    this.borderWidth = 2,
    super.key,
  });

  final Widget child;
  final double radius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(
      (radius - borderWidth).clamp(0, double.infinity),
    ),
    child: child,
  );
}

class NeoLabel extends StatelessWidget {
  const NeoLabel(
    this.text, {
    super.key,
    this.color = NeoColors.surface,
    this.textColor = NeoColors.ink,
    this.icon,
  });

  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontFamily: NeoFont.display,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum NeoButtonVariant { primary, secondary, accent, outline }

class NeoButton extends StatefulWidget {
  const NeoButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NeoButtonVariant.primary,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NeoButtonVariant variant;
  final bool expand;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _pressed = false;

  Color get _fill => switch (widget.variant) {
    NeoButtonVariant.primary => NeoColors.teal,
    NeoButtonVariant.secondary => NeoColors.surface,
    NeoButtonVariant.accent => NeoColors.surface,
    NeoButtonVariant.outline => NeoColors.surface,
  };

  void _setPressed(bool value) {
    if (widget.onPressed == null || _pressed == value) return;
    if (value) Haptics.press();
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      transform: Matrix4.translationValues(
        _pressed ? 4 : 0,
        _pressed ? 4 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: _fill,
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: _pressed
            ? const []
            : const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 17, color: NeoColors.ink),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeoColors.ink,
                fontFamily: NeoFont.display,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: Semantics(
        button: true,
        enabled: widget.onPressed != null,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: widget.expand
              ? SizedBox(width: double.infinity, child: content)
              : content,
        ),
      ),
    );
  }
}

class NeoSwitch extends StatelessWidget {
  const NeoSwitch({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      enabled: onChanged != null,
      child: InkWell(
        onTap: onChanged == null
            ? null
            : () {
                Haptics.select();
                onChanged!(!value);
              },
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value ? NeoColors.accent : NeoColors.switchOff,
                  border: Border.all(color: NeoColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: NeoColors.ink,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 120),
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: value ? NeoColors.ink : NeoColors.surface,
                      border: Border.all(color: NeoColors.ink, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // A long label wraps instead of running off the screen.
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The neo-brutalist press: while a finger is down (or while [sunken] is set) the
/// thing slides onto its own hard shadow and the shadow disappears, as if it were
/// pushed into the page. [builder] draws the thing and should take its shadow from
/// [NeoPress.shadow] with the `pressed` it is given.
///
/// With no [onTap] and no [onLongPress] it only shows [sunken].
class NeoPress extends StatefulWidget {
  const NeoPress({
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.offset = const Offset(4, 4),
    this.sunken = false,
    this.haptic = true,
    super.key,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the shadow reaches; the thing moves by the same amount.
  final Offset offset;

  /// Stays pressed in (a selected or worn thing).
  final bool sunken;
  final bool haptic;

  /// A hard black shadow [offset] away, or none while [pressed].
  static List<BoxShadow> shadow(
    bool pressed, {
    Offset offset = const Offset(4, 4),
  }) => pressed
      ? const []
      : [BoxShadow(color: NeoColors.ink, offset: offset, blurRadius: 0)];

  @override
  State<NeoPress> createState() => _NeoPressState();
}

class _NeoPressState extends State<NeoPress> {
  bool _down = false;

  bool get _active => widget.onTap != null || widget.onLongPress != null;

  void _set(bool value) {
    if (!_active || _down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down || widget.sunken;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.light();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          pressed ? widget.offset.dx : 0,
          pressed ? widget.offset.dy : 0,
          0,
        ),
        child: widget.builder(context, pressed),
      ),
    );
  }
}

class NeoIconButton extends StatelessWidget {
  const NeoIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill = NeoColors.paper,
    this.size = 40,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color fill;

  /// Side of the square; below 40 the button is the compact version (thinner
  /// shadow, smaller icon) that sits beside the status pills.
  final double size;

  @override
  Widget build(BuildContext context) {
    final offset = size < 40 ? const Offset(2, 2) : const Offset(4, 4);
    return Tooltip(
      message: tooltip,
      child: NeoPress(
        onTap: onPressed,
        offset: offset,
        builder: (context, pressed) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(size < 40 ? 999 : 8),
            boxShadow: NeoPress.shadow(pressed, offset: offset),
          ),
          child: Icon(icon, color: NeoColors.ink, size: size * 0.55),
        ),
      ),
    );
  }
}

/// The app's ink-black floating snack bar.
void showNeoSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: NeoColors.surface,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: NeoColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
}
