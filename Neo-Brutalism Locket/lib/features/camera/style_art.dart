import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/starry_night.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/quest/quest_art.dart';

/// The picture behind a style pill: plain white for no style, a pixel-art game
/// screen for 8-bit and Starry Night for Van Gogh. A cream gradient sits over
/// it, strongest in the middle, so the label stays readable and the picture
/// shows at the ends.
class StyleArt extends StatelessWidget {
  const StyleArt({required this.style, this.veil = 0.82, super.key});

  final StyleType style;

  /// Cream opacity in the middle of the gradient.
  final double veil;

  @override
  Widget build(BuildContext context) {
    if (style == StyleType.none)
      return const ColoredBox(color: Color(0xFFF8EED2));
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: switch (style) {
            StyleType.pixel8bit => const CustomPaint(
              painter: QuestArtPainter('px_mushroom'),
            ),
            _ => const CustomPaint(painter: StarryNightPainter()),
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NeoColors.surface.withValues(alpha: 0.35),
                NeoColors.surface.withValues(alpha: veil),
                NeoColors.surface.withValues(alpha: veil),
                NeoColors.surface.withValues(alpha: 0.35),
              ],
              stops: const [0, 0.3, 0.7, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small label-sized pill with the style's picture behind its name.
class StyleChip extends StatelessWidget {
  const StyleChip({
    required this.style,
    required this.text,
    this.icon,
    super.key,
  });

  final StyleType style;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeoColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: NeoPanelClip(
        radius: 999,
        child: Stack(
          children: [
            Positioned.fill(child: StyleArt(style: style, veil: 0.78)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 13, color: NeoColors.ink),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontFamily: NeoFont.display,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
