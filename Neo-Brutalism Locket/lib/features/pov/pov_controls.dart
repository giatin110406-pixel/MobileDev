import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/capture_options.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The camera's controls, the same on both phones in a session: the light and the timer
/// on the left, the shutter in the middle and the flip on the right. A press on the
/// shutter takes a photo on both phones, whichever one it was pressed on.
class PovControls extends StatelessWidget {
  const PovControls({
    required this.ready,
    required this.busy,
    required this.front,
    required this.torch,
    required this.timer,
    required this.counting,
    required this.onShutter,
    required this.onTorch,
    required this.onFlip,
    required this.onTimer,
    super.key,
  });

  /// The picture is there, so the controls work.
  final bool ready;

  /// A photo is being taken.
  final bool busy;

  /// The camera in use is the front one (it has no light).
  final bool front;
  final bool torch;
  final ShotTimer timer;

  /// A countdown is running.
  final bool counting;

  final VoidCallback onShutter;
  final VoidCallback onTorch;
  final VoidCallback onFlip;
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeoIconButton(
                    icon: torch ? Icons.flash_on : Icons.flash_off,
                    tooltip: l10n.flashTooltip,
                    onPressed: front || !ready ? null : onTorch,
                    fill: torch ? NeoColors.accent : NeoColors.surface,
                    size: 54,
                  ),
                  const SizedBox(width: 12),
                  NeoIconButton(
                    icon: switch (timer) {
                      ShotTimer.off => Icons.timer_off_outlined,
                      ShotTimer.three => Icons.timer_3,
                      ShotTimer.ten => Icons.timer_10,
                    },
                    tooltip: timer == ShotTimer.off
                        ? l10n.timerOff
                        : l10n.timerSeconds(timer.seconds),
                    onPressed: counting ? null : onTimer,
                    fill: timer == ShotTimer.off
                        ? NeoColors.surface
                        : NeoColors.coral,
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
        ),
        PovShutter(
          disabled: busy || !ready || counting,
          busy: busy,
          onTap: onShutter,
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: NeoIconButton(
                icon: Icons.flip_camera_ios_outlined,
                tooltip: l10n.switchCameraTooltip,
                onPressed: ready ? onFlip : null,
                fill: NeoColors.accent,
                size: 54,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The same shutter button as on the camera page.
class PovShutter extends StatefulWidget {
  const PovShutter({
    required this.disabled,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final bool disabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<PovShutter> createState() => _PovShutterState();
}

class _PovShutterState extends State<PovShutter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disabled = widget.disabled;
    return Semantics(
      button: true,
      label: l10n.takePhotoLabel,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(7),
            transform: Matrix4.translationValues(
              _down && !disabled ? 4 : 0,
              _down && !disabled ? 4 : 0,
              0,
            ),
            decoration: BoxDecoration(
              color: disabled ? NeoColors.switchOff : NeoColors.ink,
              shape: BoxShape.circle,
              border: Border.all(color: NeoColors.ink, width: 2),
              boxShadow: disabled || _down
                  ? const []
                  : const [
                      BoxShadow(
                        color: NeoColors.ink,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NeoColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: NeoColors.surface, width: 2),
              ),
              child: widget.busy
                  ? const Padding(
                      padding: EdgeInsets.all(17),
                      child: CircularProgressIndicator(
                        color: NeoColors.ink,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The timer's number, big on the viewfinder.
class PovCountdown extends StatelessWidget {
  const PovCountdown(this.seconds, {super.key});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: NeoTheme.panel(color: NeoColors.accent, radius: 999),
        child: Text(
          '$seconds',
          style: const TextStyle(
            fontFamily: NeoFont.display,
            color: NeoColors.ink,
            fontSize: 44,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// The white flash over the viewfinder and the "photo taken" line under it, which
/// pops in the moment a photo is taken (on either phone) and gives way to [note].
class PovFlash extends StatelessWidget {
  const PovFlash({required this.on, super.key});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: on ? 0.85 : 0,
        duration: const Duration(milliseconds: 120),
        child: const ColoredBox(color: Colors.white),
      ),
    );
  }
}

class PovSnapLine extends StatelessWidget {
  const PovSnapLine({required this.snapped, required this.note, super.key});

  final bool snapped;
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 40,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: snapped
              ? NeoLabel(
                  l10n.povSnapBoth,
                  key: const ValueKey('snap'),
                  color: NeoColors.accent,
                  icon: Icons.camera_alt_outlined,
                )
              : Text(
                  note,
                  key: const ValueKey('note'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
