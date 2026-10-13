import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

// ---------------------------------------------------------------------------
// NeoBottomNavTab – data class describing a single tab in the nav bar.
// ---------------------------------------------------------------------------

/// Describes one tab inside [NeoBottomNav].
///
/// Each tab carries two icon variants (outline for idle, filled for active)
/// and an [activeColor]: the colour of the block behind the selected tab.
class NeoBottomNavTab {
  const NeoBottomNavTab({
    required this.label,
    required this.outlineIcon,
    required this.filledIcon,
    required this.activeColor,
  });

  /// Accessible name used by tooltips and screen readers.
  final String label;

  /// Icon displayed when the tab is **not** selected.
  final IconData outlineIcon;

  /// Icon displayed when the tab **is** selected.
  final IconData filledIcon;

  /// The colour of the block behind the icon while the tab is selected.
  final Color activeColor;
}

/// The colours of the bar: an 80s / 90s arcade palette. A deep violet bar, a racing
/// stripe along the top, and one loud colour for every tab.
abstract final class NeoNavColors {
  static const bar = Color(0xFF2B1A5E);
  static const pink = Color(0xFFFF3D9A);
  static const orange = Color(0xFFFF8A00);
  static const yellow = Color(0xFFFFE600);
  static const mint = Color(0xFF39FF9E);
  static const cyan = Color(0xFF00E5FF);

  /// The racing stripe along the top of the bar, left to right.
  static const stripe = [pink, orange, yellow, mint, cyan];
}

// ---------------------------------------------------------------------------
// NeoBottomNav – the chunky bottom navigation bar.
// ---------------------------------------------------------------------------

/// A neo-brutalism–styled bottom navigation bar with a retro look: a dark violet
/// bar with a racing stripe, light icons, and a solid coloured block with a black
/// outline and a hard shadow behind the selected tab.
///
/// Only one tab may be selected at a time. Selection is driven externally via
/// [selectedIndex]; tapping a tab calls [onSelected]. The app shell owns haptics.
///
class NeoBottomNav extends StatelessWidget {
  const NeoBottomNav({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onSelected,
  });

  /// Index of the currently selected tab (0-based).
  final int selectedIndex;

  /// Ordered list of tabs to render. Length determines column count.
  final List<NeoBottomNavTab> tabs;

  /// Called with the tapped tab's index when a user selects a tab.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 18, top: 4, bottom: 8),
        child: Container(
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: NeoNavColors.bar,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: NeoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // The racing stripe.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final colour in NeoNavColors.stripe)
                      Expanded(child: ColoredBox(color: colour)),
                  ],
                ),
              ),
              Positioned.fill(
                top: 5,
                child: Row(
                  children: List.generate(tabs.length, (index) {
                    return _NeoNavItem(
                      tab: tabs[index],
                      selected: index == selectedIndex,
                      onTap: () => onSelected(index),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NeoNavItem – a single tab inside the bar (private).
// ---------------------------------------------------------------------------

/// An icon-only tab with an accessible name. The selected one sits on a solid
/// coloured block.
class _NeoNavItem extends StatelessWidget {
  const _NeoNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final NeoBottomNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: tab.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox.expand(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  width: 48,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected ? tab.activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? NeoColors.ink : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: NeoColors.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: Icon(
                      selected ? tab.filledIcon : tab.outlineIcon,
                      size: 24,
                      color: selected ? NeoColors.ink : NeoColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
