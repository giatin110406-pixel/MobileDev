import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

abstract final class NeoColors {
  // Yellow is the ground; the rest is placed on it:
  //   yellow    (50%) - the ground of every screen: the app's main colour
  //   off-white (30%) - cards, the tab bar, sheets
  //   green     (10%) - the thing to press or the thing selected: buttons,
  //                     selected tab and chips, labels, my chat bubbles
  //   coral     (10%) - alerts and unread counts (REC, errors, closed)
  //   black             outlines, hard shadows and text
  static const ink = Color(0xFF000000);
  static const yellow = Color(0xFFFFD23F);
  static const paper = yellow;
  static const surface = Color(0xFFFFFDF5);
  static const green = Color(0xFF88D498);
  static const coral = Color(0xFFFF6B6B);
  static const muted = Color(0xFF5C5C5C);
  static const switchOff = Color(0xFFECE8DA);
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
      secondary: NeoColors.green,
      onSecondary: NeoColors.ink,
      surface: NeoColors.surface,
      onSurface: NeoColors.ink,
      error: NeoColors.coral,
      onError: NeoColors.ink,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NeoColors.ink,
      selectionColor: NeoColors.green,
      selectionHandleColor: NeoColors.ink,
    ),
    splashFactory: NoSplash.splashFactory,
    fontFamily: NeoFont.body,
  );

  static BoxDecoration panel({
    Color color = NeoColors.surface,
    double borderWidth = 2,
    double radius = 8,
  }) => BoxDecoration(
    color: color,
    border: Border.all(color: NeoColors.ink, width: borderWidth),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(color: NeoColors.ink, offset: Offset(4, 4), blurRadius: 0),
    ],
  );
}

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
    NeoButtonVariant.primary => NeoColors.green,
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
                  color: value ? NeoColors.yellow : NeoColors.switchOff,
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
                      color: NeoColors.surface,
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

class NeoIconButton extends StatelessWidget {
  const NeoIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill = NeoColors.paper,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  Haptics.light();
                  onPressed!();
                },
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: NeoColors.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, color: NeoColors.ink, size: 22),
          ),
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
