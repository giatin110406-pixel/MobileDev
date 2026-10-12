import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

// ---------------------------------------------------------------------------
// NeoBottomNavTab – data class describing a single tab in the nav bar.
// ---------------------------------------------------------------------------

/// Describes one tab inside [NeoBottomNav].
///
/// Each tab carries two icon variants (outline for idle, filled for active)
/// and an [activeColor] used for the icon tint and the selection pill.
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

  /// Accent colour used for the selected icon tint and pill background blend.
  final Color activeColor;
}

// ---------------------------------------------------------------------------
// NeoBottomNav – the pill-shaped bottom navigation bar.
// ---------------------------------------------------------------------------

/// A neo-brutalism–styled bottom navigation bar rendered as a rounded pill.
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
          decoration: BoxDecoration(
            color: NeoColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: NeoColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NeoNavItem – a single tab inside the bar (private).
// ---------------------------------------------------------------------------

/// An icon-only tab with an accessible name and a coloured selection pill.
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
    // Pill background: 22 % tab colour blended with 78 % surface.
    final pillColor = Color.lerp(tab.activeColor, NeoColors.surface, 0.78)!;

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
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? pillColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Icon(
                      selected ? tab.filledIcon : tab.outlineIcon,
                      size: 24,
                      color: selected ? tab.activeColor : NeoColors.ink,
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
