import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Marks controls whose pointer gestures must never change the main tab.
class TabSwipeExclusion extends SingleChildRenderObjectWidget {
  const TabSwipeExclusion({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _ExcludedRegion();
}

class _ExcludedRegion extends RenderProxyBox {}

class _TabDragRecognizer extends HorizontalDragGestureRecognizer {
  _TabDragRecognizer({required this.isControlHit});

  final bool Function(Set<HitTestTarget>) isControlHit;

  @override
  bool isPointerAllowed(PointerEvent event) {
    final hit = HitTestResult();
    RendererBinding.instance.hitTestInView(hit, event.position, event.viewId);
    if (hit.path.any(
      (entry) =>
          entry.target is _ExcludedRegion || entry.target is RenderEditable,
    )) {
      return false;
    }
    if (isControlHit(hit.path.map((entry) => entry.target).toSet())) {
      return false;
    }
    return super.isPointerAllowed(event);
  }
}

/// Switches once on release; child drag recognizers keep gesture priority.
class TabSwipeDetector extends StatefulWidget {
  const TabSwipeDetector({
    super.key,
    required this.tabCount,
    required this.currentIndex,
    required this.onSwipe,
    required this.child,
  });

  final int tabCount;
  final int currentIndex;
  final ValueChanged<int> onSwipe;
  final Widget child;

  @override
  State<TabSwipeDetector> createState() => _TabSwipeDetectorState();
}

class _TabSwipeDetectorState extends State<TabSwipeDetector> {
  final Set<int> _pointers = {};
  bool _multiplePointers = false;
  double _distance = 0;

  bool _isControlHit(Set<HitTestTarget> targets) {
    var excluded = false;
    void visit(Element element) {
      if (excluded) return;
      if (element is RenderObjectElement &&
          !targets.contains(element.renderObject)) {
        return;
      }
      final control = element.widget;
      if (control is Slider ||
          control is RangeSlider ||
          control is SelectionArea ||
          control is SelectableRegion) {
        excluded = true;
        return;
      }
      element.visitChildElements(visit);
    }

    (context as Element).visitChildElements(visit);
    return excluded;
  }

  void _down(PointerDownEvent event) {
    if (_pointers.isEmpty) _multiplePointers = false;
    _pointers.add(event.pointer);
    if (_pointers.length > 1) _multiplePointers = true;
  }

  void _end(DragEndDetails details) {
    final distance = _distance;
    _distance = 0;
    if (_multiplePointers) return;
    final velocity = details.primaryVelocity ?? 0;
    final enough =
        distance.abs() >= 48 ||
        (distance.abs() >= 16 &&
            velocity.abs() >= 450 &&
            distance.sign == velocity.sign);
    if (!enough) return;
    final next = widget.currentIndex + (distance < 0 ? 1 : -1);
    if (next >= 0 && next < widget.tabCount) widget.onSwipe(next);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: (event) => _pointers.remove(event.pointer),
      onPointerCancel: (event) => _pointers.remove(event.pointer),
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          _TabDragRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _TabDragRecognizer
              >(() => _TabDragRecognizer(isControlHit: _isControlHit), (
                recognizer,
              ) {
                recognizer.dragStartBehavior = DragStartBehavior.down;
                recognizer.gestureSettings = const DeviceGestureSettings(
                  touchSlop: 15,
                );
                // The app applies its own 16px minimum after velocity tracking.
                recognizer.minFlingDistance = 0;
                recognizer.onStart = (_) {
                  _distance = 0;
                };
                recognizer.onUpdate = (details) {
                  _distance += details.primaryDelta ?? 0;
                };
                recognizer.onEnd = _end;
                recognizer.onCancel = () {
                  _distance = 0;
                };
              }),
        },
        child: widget.child,
      ),
    );
  }
}
