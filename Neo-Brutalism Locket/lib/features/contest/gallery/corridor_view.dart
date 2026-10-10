import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Walk down the Gallery: swipe up to go forward, down to go back (or use the
/// scroll wheel or the two arrow buttons). The pictures slide past on both
/// walls; tap one to open it.
class CorridorView extends StatefulWidget {
  const CorridorView({
    required this.entries,
    required this.cache,
    required this.onOpen,
    this.onNearEnd,
    this.initialCameraZ = 0,
    super.key,
  });

  final List<GalleryEntry> entries;
  final EntryImageCache cache;
  final ValueChanged<GalleryEntry> onOpen;

  /// Called when the visitor is close to the end of what is loaded.
  final VoidCallback? onNearEnd;
  final double initialCameraZ;

  @override
  State<CorridorView> createState() => _CorridorViewState();
}

class _CorridorViewState extends State<CorridorView>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _camera = ValueNotifier(
    widget.initialCameraZ,
  );
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onMotion);
  late List<FrameSlot> _slots = layoutFrames(_ids);
  bool _lite = false;
  final List<int> _frameMicros = [];

  List<String> get _ids => [for (final entry in widget.entries) entry.id];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void didUpdateWidget(CorridorView old) {
    super.didUpdateWidget(old);
    final changed =
        old.entries.length != widget.entries.length ||
        !_sameIds(old.entries, widget.entries);
    if (changed) _slots = layoutFrames(_ids);
  }

  bool _sameIds(List<GalleryEntry> a, List<GalleryEntry> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _motion.dispose();
    _camera.dispose();
    super.dispose();
  }

  /// A phone that needs more than ~22 ms for a frame switches to the lighter
  /// look (no gradients, planks or light pools).
  void _onTimings(List<FrameTiming> timings) {
    if (_lite || !mounted) return;
    for (final timing in timings) {
      _frameMicros.add(timing.totalSpan.inMicroseconds);
    }
    if (_frameMicros.length < 90) return;
    final recent = _frameMicros.sublist(_frameMicros.length - 90);
    final average = recent.reduce((a, b) => a + b) / recent.length;
    if (average > 22000) {
      setState(() => _lite = true);
    }
    if (_frameMicros.length > 400) {
      _frameMicros.removeRange(0, _frameMicros.length - 90);
    }
  }

  double get _max => math.max(0, corridorLength(_slots) - 4);

  void _set(double z) {
    final clamped = z.clamp(0.0, _max);
    _camera.value = clamped;
    if (widget.onNearEnd != null && clamped > _max - 14) widget.onNearEnd!();
  }

  void _onMotion() => _set(_motion.value);

  void _fling(double velocity) {
    _motion.value = _camera.value;
    _motion.animateWith(FrictionSimulation(0.12, _camera.value, velocity));
  }

  void _walk(double metres) {
    _motion.stop();
    _motion.value = _camera.value;
    _motion.animateTo(
      (_camera.value + metres).clamp(0.0, _max),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  static const _metresPerPixel = 0.012;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: AppLocalizations.of(
        context,
      ).corridorSemantics(widget.entries.length),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _motion.stop();
                    _set(_camera.value + event.scrollDelta.dy * 0.01);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _motion.stop(),
                  onVerticalDragUpdate: (d) =>
                      _set(_camera.value - d.delta.dy * _metresPerPixel),
                  onVerticalDragEnd: (d) =>
                      _fling(-d.velocity.pixelsPerSecond.dy * _metresPerPixel),
                  onTapUp: (d) {
                    final slot = hitTest(
                      d.localPosition,
                      _slots,
                      Projection(size, _camera.value),
                    );
                    if (slot != null) widget.onOpen(widget.entries[slot.index]);
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: CorridorPainter(
                        camera: _camera,
                        entries: widget.entries,
                        slots: _slots,
                        cache: widget.cache,
                        lite: _lite,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NeoIconButton(
                      icon: Icons.keyboard_arrow_up,
                      tooltip: AppLocalizations.of(context).walkForward,
                      onPressed: () => _walk(4),
                    ),
                    const SizedBox(height: 10),
                    NeoIconButton(
                      icon: Icons.keyboard_arrow_down,
                      tooltip: AppLocalizations.of(context).walkBack,
                      onPressed: () => _walk(-4),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                bottom: 16,
                child: ValueListenableBuilder<double>(
                  valueListenable: _camera,
                  builder: (context, z, _) => NeoLabel(
                    _position(z),
                    color: NeoColors.yellow,
                    icon: Icons.directions_walk,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// "Tranh 12 / 87": the frame nearest ahead of the visitor.
  String _position(double z) {
    if (_slots.isEmpty) return '0 / 0';
    FrameSlot? ahead;
    for (final slot in _slots) {
      if (slot.z1 > z + 0.5 && (ahead == null || slot.z0 < ahead.z0)) {
        ahead = slot;
      }
    }
    final index = (ahead?.index ?? _slots.length - 1) + 1;
    // A "+" while more pages are still to be loaded.
    final more = widget.onNearEnd != null ? '+' : '';
    return '$index / ${widget.entries.length}$more';
  }
}
