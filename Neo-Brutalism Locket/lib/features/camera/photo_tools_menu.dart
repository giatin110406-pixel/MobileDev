import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// One thing that can be done to the shot just taken (besides styling and
/// posting it), as a row of the photo tools menu.
@immutable
class PhotoTool {
  const PhotoTool({
    required this.icon,
    required this.label,
    required this.run,
    this.color = NeoColors.teal,
  });

  final IconData icon;
  final String label;
  final VoidCallback run;

  /// The colour of the icon's chip.
  final Color color;
}

/// A small button that opens the menu of photo tools; nothing while there are
/// none, so a new tool is one more entry in the list and the page keeps its
/// single button.
class PhotoToolsButton extends StatefulWidget {
  const PhotoToolsButton({
    super.key,
    required this.tools,
    required this.title,
    required this.tooltip,
  });

  final List<PhotoTool> tools;

  /// The menu's heading.
  final String title;
  final String tooltip;

  @override
  State<PhotoToolsButton> createState() => _PhotoToolsButtonState();
}

class _PhotoToolsButtonState extends State<PhotoToolsButton> {
  bool _open = false;

  Future<void> _show() async {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _open = true);
    final run = await Navigator.of(context).push<VoidCallback>(
      PageRouteBuilder<VoidCallback>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        barrierLabel: widget.tooltip,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 110),
        pageBuilder: (context, animation, _) =>
            _Menu(anchor: anchor, title: widget.title, tools: widget.tools),
        transitionsBuilder: (context, animation, _, child) {
          // Pops out of the button with a little overshoot, and a tilt that
          // settles: a sticker slapped on, not a fade.
          final pop = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.4),
            ),
            child: AnimatedBuilder(
              animation: pop,
              builder: (context, child) => Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.identity()
                  ..scaleByDouble(
                    0.8 + 0.2 * pop.value,
                    0.8 + 0.2 * pop.value,
                    1,
                    1,
                  )
                  ..rotateZ(-0.05 * (1 - pop.value)),
                child: child,
              ),
              child: child,
            ),
          );
        },
      ),
    );
    if (mounted) setState(() => _open = false);
    if (run != null && mounted) run();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tools.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: widget.tooltip,
      child: NeoPress(
        onTap: _show,
        offset: const Offset(3, 3),
        sunken: _open,
        builder: (context, pressed) => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: NeoColors.accent,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: NeoPress.shadow(pressed, offset: const Offset(3, 3)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.auto_fix_high, size: 22, color: NeoColors.ink),
              // A small corner tick: there is a menu behind this.
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: NeoColors.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.arrow_drop_down,
                    size: 8,
                    color: NeoColors.accent,
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

class _Menu extends StatelessWidget {
  const _Menu({required this.anchor, required this.title, required this.tools});

  final Rect anchor;
  final String title;
  final List<PhotoTool> tools;

  static const _width = 232.0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = anchor.left.clamp(12.0, screen.width - _width - 16);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: anchor.bottom + 12,
          width: _width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The notch pointing at the button: a black diamond that grows
              // out of the black heading.
              Positioned(
                left: (anchor.center.dx - left - 8).clamp(14.0, _width - 34),
                top: -7,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: NeoColors.ink,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              Container(
                decoration:
                    NeoTheme.panel(
                      color: NeoColors.surface,
                      borderWidth: 2.5,
                      radius: 14,
                    ).copyWith(
                      boxShadow: NeoPress.shadow(
                        false,
                        offset: const Offset(5, 5),
                      ),
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11.5),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: NeoColors.ink,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: NeoFont.display,
                              color: NeoColors.surface,
                              fontSize: 11,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        for (var i = 0; i < tools.length; i++) ...[
                          if (i > 0) Container(height: 2, color: NeoColors.ink),
                          _Row(tool: tools[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.tool});

  final PhotoTool tool;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Haptics.light();
        Navigator.of(context).pop(tool.run);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        color: _down ? NeoColors.accent : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tool.color,
                border: Border.all(color: NeoColors.ink, width: 2),
                borderRadius: BorderRadius.circular(10),
                boxShadow: NeoPress.shadow(_down, offset: const Offset(2, 2)),
              ),
              child: Icon(tool.icon, size: 20, color: NeoColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tool.label,
                style: const TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18, color: NeoColors.ink),
          ],
        ),
      ),
    );
  }
}
