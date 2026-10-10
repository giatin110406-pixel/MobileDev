import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

abstract final class NeoColors {
  static const paper = Color(0xFFECE6C2);
  static const surface = Color(0xFFFDF2E9);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B6B6B);
  static const pink = Color(0xFFFF6B6B);
  static const purple = Color(0xFFA388EE);
  static const teal = Color(0xFF4ECDC4);
  static const yellow = Color(0xFFFFE66D);
  static const blue = Color(0xFF45B7D1);
  static const orange = Color(0xFFF7A072);
  static const switchOff = Color(0xFFE8E0D4);

  static const lime = teal;
  static const cyan = blue;
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
      secondary: NeoColors.teal,
      onSecondary: NeoColors.ink,
      surface: NeoColors.surface,
      onSurface: NeoColors.ink,
      error: NeoColors.orange,
      onError: NeoColors.ink,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NeoColors.ink,
      selectionColor: NeoColors.lime,
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

class NeoLabel extends StatelessWidget {
  const NeoLabel(
    this.text, {
    super.key,
    this.color = NeoColors.lime,
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
    NeoButtonVariant.primary => NeoColors.pink,
    NeoButtonVariant.secondary => NeoColors.purple,
    NeoButtonVariant.accent => NeoColors.teal,
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
                  color: value ? NeoColors.teal : NeoColors.switchOff,
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
              Text(
                label,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
