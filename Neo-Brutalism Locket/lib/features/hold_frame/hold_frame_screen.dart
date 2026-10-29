import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/hold_frame/hold_frame_backend.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_preview.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Lock the composition, hand over the phone, then let its recipient start guidance.
/// Returns a full-quality square JPEG through the normal photo composer.
class HoldFrameScreen extends StatefulWidget {
  const HoldFrameScreen({super.key, this.backend});
  final HoldFrameBackend? backend;

  @override
  State<HoldFrameScreen> createState() => _HoldFrameScreenState();
}

class _HoldFrameScreenState extends State<HoldFrameScreen>
    with WidgetsBindingObserver {
  late final _backend = widget.backend ?? MethodChannelHoldFrameBackend();
  StreamSubscription<HoldFrameUpdate>? _events;
  Timer? _watchdog;
  Future<void>? _stopping;
  RewindStart? _start;
  Uint8List? _ghost;
  HoldFrameUpdate? _alignment;
  DateTime? _lastUpdate;
  String? _error;
  bool _opening = true;
  bool _locking = false;
  bool _armed = false;
  bool _arming = false;
  bool _shooting = false;
  bool _leaving = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _events = _backend.updates.listen(
      _onUpdate,
      onError: (Object _) {
        _onUpdate(const HoldFrameUpdate(state: 'error'));
      },
    );
    _open();
    _watchdog = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted || _leaving || _ghost == null || _shooting) return;
      if (_lastUpdate != null &&
          DateTime.now().difference(_lastUpdate!) >
              const Duration(milliseconds: 600) &&
          _alignment?.reason != 'stale') {
        setState(
          () => _alignment = const HoldFrameUpdate(
            state: 'unsure',
            reason: 'stale',
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && !_leaving) {
      _backend.arm(false).ignore();
      setState(() {
        _armed = false;
        _alignment = const HoldFrameUpdate(state: 'unsure', reason: 'stale');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _events?.cancel();
    _shutdown().ignore();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _shutdown() => _stopping ??= _backend.stop();

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final start = await _backend.start();
      if (!mounted || _leaving) return;
      setState(() {
        _start = start;
        _opening = false;
      });
    } catch (_) {
      if (mounted && !_leaving) {
        setState(() {
          _opening = false;
          _error = 'camera';
        });
      }
    }
  }

  void _onUpdate(HoldFrameUpdate update) {
    if (!mounted || _leaving || !_foreground || _shooting) return;
    if (update.state == 'error') {
      _backend.arm(false).ignore();
      setState(() {
        _armed = false;
        _error = 'camera';
      });
      return;
    }
    if (_ghost == null) return;
    _lastUpdate = DateTime.now();
    setState(() => _alignment = update);
    if (_armed && update.state == 'aligned' && update.ready) _capture();
  }

  Future<void> _lock() async {
    if (_locking || _shooting || _leaving) return;
    setState(() {
      _locking = true;
      _error = null;
    });
    try {
      final ghost = await _backend.lock();
      if (!mounted || _leaving) return;
      Haptics.select();
      setState(() {
        _ghost = ghost;
        _alignment = null;
        _lastUpdate = null;
        _armed = false;
      });
    } on PlatformException catch (e) {
      if (mounted && !_leaving) setState(() => _error = e.code);
    } catch (_) {
      if (mounted && !_leaving) setState(() => _error = 'holdUnavailable');
    } finally {
      if (mounted) setState(() => _locking = false);
    }
  }

  Future<void> _arm() async {
    if (_arming || !_foreground) return;
    final on = !_armed;
    setState(() {
      _arming = true;
      _error = null;
    });
    try {
      await _backend.arm(on);
      if (!mounted || _leaving) return;
      if (!_foreground) {
        await _backend.arm(false);
        return;
      }
      setState(() => _armed = on);
    } catch (_) {
      if (mounted && !_leaving) setState(() => _error = 'holdUnavailable');
    } finally {
      if (mounted) setState(() => _arming = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _armed = false;
      _ghost = null;
      _alignment = null;
      _error = null;
    });
    try {
      await _backend.unlock();
    } catch (_) {
      if (mounted) setState(() => _error = 'holdUnavailable');
    }
  }

  Future<void> _capture() async {
    if (_shooting || !_foreground || _leaving) return;
    setState(() {
      _shooting = true;
      _armed = false;
    });
    Haptics.press();
    try {
      final bytes = await _backend.capture();
      if (mounted && !_leaving) await _close(bytes);
    } catch (_) {
      if (mounted && !_leaving) {
        setState(() {
          _shooting = false;
          _error = 'capture';
        });
      }
    }
  }

  Future<void> _close([Uint8List? bytes]) async {
    if (_leaving) return;
    _leaving = true;
    _watchdog?.cancel();
    // _leaving already drops late updates; do not let a slow cancel hold the camera.
    _events?.cancel().ignore();
    _events = null;
    try {
      await _shutdown();
    } finally {
      if (mounted) Navigator.of(context).pop(bytes);
    }
  }

  String _status(AppLocalizations l) {
    if (_error != null) {
      return switch (_error) {
        'holdFewFeatures' => l.holdFrameFewFeatures,
        'holdNoFrame' => l.holdFrameStale,
        'capture' => l.photoNotSaved,
        'camera' => l.cameraUnavailable,
        _ => l.holdFrameUnavailable,
      };
    }
    if (_shooting) return l.holdFrameCapturing;
    if (_ghost == null) return l.holdFrameChoose;
    if (!_armed) return l.holdFrameHandoff;
    final a = _alignment;
    if (a == null || a.reason == 'stale') return l.holdFrameStale;
    if (a.state == 'unsure') return l.holdFrameUnsure;
    if (a.state == 'aligned') return l.holdFrameSteady;
    return [
      if (a.dx.abs() > .03) a.dx > 0 ? l.holdFrameRight : l.holdFrameLeft,
      if (a.dy.abs() > .03) a.dy > 0 ? l.holdFrameDown : l.holdFrameUp,
      if (a.roll.abs() > 2)
        a.roll > 0 ? l.holdFrameClockwise : l.holdFrameCounterclockwise,
      if ((a.scale - 1).abs() > .04)
        a.scale > 1 ? l.holdFrameBack : l.holdFrameCloser,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = _alignment;
    final canGuide = _armed && a != null && a.state != 'unsure';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l.holdFrameTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            onPressed: _close,
            tooltip: l.closeAction,
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.holdFrameIntro),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: NeoTheme.panel(),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_start != null)
                            RewindPreview(start: _start!)
                          else
                            const ColoredBox(color: NeoColors.ink),
                          if (_ghost != null)
                            // dx/dy are fractions of the square, so move the
                            // ghost by the square's real size on this screen.
                            LayoutBuilder(
                              builder: (context, box) => Opacity(
                                opacity: .28,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..translateByDouble(
                                      canGuide ? a.dx * box.maxWidth : 0,
                                      canGuide ? a.dy * box.maxHeight : 0,
                                      0,
                                      1,
                                    )
                                    ..rotateZ(
                                      canGuide ? a.roll * math.pi / 180 : 0,
                                    )
                                    ..scaleByDouble(
                                      canGuide ? a.scale : 1,
                                      canGuide ? a.scale : 1,
                                      1,
                                      1,
                                    ),
                                  child: Image.memory(
                                    _ghost!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                            ),
                          if (_opening || _locking || _shooting)
                            const Center(child: CircularProgressIndicator()),
                          if (canGuide && a.state == 'adjust')
                            Center(
                              child: Icon(
                                a.dx.abs() > .03
                                    ? (a.dx > 0
                                          ? Icons.arrow_forward
                                          : Icons.arrow_back)
                                    : a.dy.abs() > .03
                                    ? (a.dy > 0
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward)
                                    : a.roll.abs() > 2
                                    ? (a.roll > 0
                                          ? Icons.rotate_right
                                          : Icons.rotate_left)
                                    : Icons.open_with,
                                size: 76,
                                color: NeoColors.accent,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 6),
                                ],
                              ),
                            ),
                          if (canGuide && a.state == 'aligned')
                            const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: NeoColors.teal,
                                size: 76,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _status(l),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!_opening && _start == null)
                  FilledButton(onPressed: _open, child: Text(l.retry))
                else if (_start != null && !_shooting) ...[
                  FilledButton.icon(
                    key: const ValueKey('hold-primary'),
                    onPressed: _locking || _arming
                        ? null
                        : _ghost == null
                        ? _lock
                        : _arm,
                    icon: Icon(
                      _ghost == null
                          ? Icons.lock_outline
                          : _armed
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      _ghost == null
                          ? l.holdFrameLock
                          : _armed
                          ? l.holdFramePause
                          : l.holdFrameStart,
                    ),
                  ),
                  if (_ghost != null)
                    TextButton(
                      onPressed: _locking || _arming ? null : _reset,
                      child: Text(l.holdFrameReset),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
