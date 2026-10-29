import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/capture_options.dart';
import 'package:neo_brutalism_locket/features/camera/square_crop.dart';
import 'package:neo_brutalism_locket/features/pov/pov_connection.dart';
import 'package:neo_brutalism_locket/features/pov/pov_controls.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

/// Omni POV, showing: I am taking the photos, and a friend watches my camera. The
/// camera is opened here for the connection (the camera page lets go of it first), and
/// this page looks like it: the square viewfinder, the shutter, the flip, the light and
/// the timer. Each photo is cut to the same square the friend sees and handed to
/// [onShot], which saves it. Photos can be taken as long as the session lasts.
class PovHostScreen extends StatefulWidget {
  const PovHostScreen({
    required this.store,
    required this.repository,
    required this.viewer,
    required this.onShot,
    super.key,
  });

  final PovStore store;
  final PovRepository repository;

  /// The friend who is watching (null when not known).
  final PocketFriend? viewer;

  /// Saves one photo: a square JPEG.
  final Future<void> Function(Uint8List squareJpeg) onShot;

  @override
  State<PovHostScreen> createState() => _PovHostScreenState();
}

class _PovHostScreenState extends State<PovHostScreen>
    with WidgetsBindingObserver {
  final _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  MediaStreamTrack? _track;
  PovHostConnection? _connection;

  bool _ready = false;
  bool _flash = false;
  bool _snapped = false;
  Timer? _snapTimer;
  bool _busy = false;
  bool _torch = false;
  bool _front = false;
  ShotTimer _timer = ShotTimer.off;
  int? _countdown;
  Timer? _countdownTimer;
  int _shots = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStore);
    unawaited(_open());
  }

  Future<void> _open() async {
    final session = widget.store.session;
    if (session == null) return;
    try {
      await _renderer.initialize();
      final stream = await _openCamera();
      _stream = stream;
      _track = stream.getVideoTracks().first;
      _renderer.srcObject = stream;
      if (mounted) setState(() => _ready = true);
      final ice = await widget.repository.iceServers();
      final connection = PovHostConnection(
        signal: widget.repository.openSignal(session.id),
        ice: ice,
        camera: stream,
      );
      _connection = connection;
      connection.link.addListener(_onLink);
      connection.onBye.listen((_) => _finish(PovEnd.ended));
      connection.onCommand.listen(_onCommand);
      connection.onGo.listen(_begin);
      await connection.start();
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).povCameraFailed)),
        );
      }
      _finish(PovEnd.lostConnection);
    }
  }

  /// The camera page has just let go of the camera, which the phone may take a moment
  /// to give back: try a few times.
  Future<MediaStream> _openCamera() async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': 'environment',
            'width': {'ideal': 1920},
            'height': {'ideal': 1080},
            'frameRate': {'ideal': 30},
          },
        });
      } catch (error, stack) {
        AppLog.warn('pov_host', error, stack);
        if (attempt >= 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  /// The friend who watches asked for something from my camera.
  void _onCommand(String command) {
    if (!mounted) return;
    switch (command) {
      case 'flip':
        unawaited(_flip());
      case 'torch':
        unawaited(_toggleTorch());
    }
  }

  void _reportState() => _connection?.sendState(front: _front, torch: _torch);

  void _onLink() {
    if (!mounted) return;
    if (_connection?.link.value == PovLink.lost) {
      _finish(PovEnd.lostConnection);
    } else {
      setState(() {});
    }
  }

  void _onStore() {
    if (!mounted) return;
    if (widget.store.session == null) {
      _close();
      return;
    }
    final shots = widget.store.session!.shots;
    if (shots > _shots) setState(() => _shots = shots);
  }

  void _finish(PovEnd reason) {
    if (_leaving) return;
    unawaited(widget.store.end(reason: reason));
    _close();
  }

  void _close() {
    if (_leaving) return;
    _leaving = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A camera cannot run in the background: the session ends.
    if (state == AppLifecycleState.paused) _finish(PovEnd.ended);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStore);
    _countdownTimer?.cancel();
    _snapTimer?.cancel();
    final connection = _connection;
    if (connection != null) {
      connection.link.removeListener(_onLink);
      unawaited(connection.close());
    }
    unawaited(_release());
    super.dispose();
  }

  /// Lets go of the camera (the camera page opens it again).
  Future<void> _release() async {
    final stream = _stream;
    _renderer.srcObject = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {
          // Already stopped.
        }
      }
      await stream.dispose();
    }
    await _renderer.dispose();
  }

  // Taking photos ----------------------------------------------------------------------

  /// The shutter was pressed here: both phones take a photo.
  void _press() {
    if (_busy || _countdown != null || !_ready) return;
    final seconds = _timer == ShotTimer.off ? 0 : _timer.seconds;
    _connection?.sendGo(seconds);
    _begin(seconds);
  }

  /// A photo in [seconds] (now when 0), asked for here or by the friend.
  void _begin(int seconds) {
    if (!mounted || _busy || _countdown != null || !_ready) return;
    Haptics.press();
    if (seconds <= 0) {
      unawaited(_capture());
      return;
    }
    setState(() => _countdown = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (_countdown ?? 1) - 1;
      if (left <= 0) {
        timer.cancel();
        setState(() => _countdown = null);
        unawaited(_capture());
      } else {
        setState(() => _countdown = left);
      }
    });
  }

  Future<void> _capture() async {
    final track = _track;
    if (track == null || _busy) return;
    setState(() {
      _busy = true;
      _flash = true;
      _snapped = true;
    });
    Haptics.heavy();
    Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _snapped = false);
    });
    try {
      final frame = await track.captureFrame();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'pov_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(frame.asUint8List(), flush: true);
      final Uint8List bytes;
      try {
        // The same centred square the friend is looking at.
        bytes = await cropShotToSquare(file.path);
      } finally {
        file.delete().ignore();
      }
      await widget.onShot(bytes);
      _shots++;
      unawaited(widget.store.reportShot());
      _connection?.sendShot(_shots);
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoNotSaved)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flip() async {
    final track = _track;
    if (track == null || _busy) return;
    try {
      await Helper.switchCamera(track);
      if (mounted) {
        setState(() {
          _front = !_front;
          _torch = false;
        });
        _reportState();
      }
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
    }
  }

  Future<void> _toggleTorch() async {
    final track = _track;
    if (track == null || _front) return;
    try {
      if (!await track.hasTorch()) return;
      await track.setTorch(!_torch);
      if (mounted) {
        setState(() => _torch = !_torch);
        _reportState();
      }
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
    }
  }

  // The page --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (widget.viewer?.name ?? '').toUpperCase();
    final link = _connection?.link.value ?? PovLink.connecting;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(PovEnd.ended);
      },
      child: Scaffold(
        backgroundColor: NeoColors.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    NeoIconButton(
                      icon: Icons.close,
                      tooltip: l10n.povHostStop,
                      onPressed: () => _finish(PovEnd.ended),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: NeoLabel(
                          switch (link) {
                            PovLink.live => l10n.povHostWatching(name),
                            PovLink.reconnecting => l10n.povReconnecting,
                            PovLink.lost => l10n.povConnectionLost,
                            _ => l10n.povConnecting,
                          },
                          color: link == PovLink.live
                              ? NeoColors.teal
                              : NeoColors.accent,
                          icon: link == PovLink.live
                              ? Icons.visibility_outlined
                              : Icons.sync,
                        ),
                      ),
                    ),
                    NeoLabel(
                      l10n.povHostShots(_shots),
                      color: NeoColors.surface,
                    ),
                  ],
                ),
                // The viewfinder takes the middle, the controls sit under the thumb.
                Expanded(
                  child: Center(
                    child: AspectRatio(aspectRatio: 1, child: _viewfinder()),
                  ),
                ),
                PovSnapLine(snapped: _snapped, note: l10n.povFramingNote),
                const SizedBox(height: 10),
                PovControls(
                  ready: _ready,
                  busy: _busy,
                  front: _front,
                  torch: _torch,
                  timer: _timer,
                  counting: _countdown != null,
                  onShutter: _press,
                  onTorch: _toggleTorch,
                  onFlip: _flip,
                  onTimer: () => setState(() => _timer = _timer.next),
                ),
                const SizedBox(height: 18),
                NeoButton(
                  expand: true,
                  label: l10n.povHostStop,
                  variant: NeoButtonVariant.outline,
                  onPressed: () => _finish(PovEnd.ended),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    return Container(
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 40),
      foregroundDecoration: neoPanelOutline(radius: 40),
      child: NeoPanelClip(
        radius: 40,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              const Center(
                child: CircularProgressIndicator(color: NeoColors.ink),
              ),
            PovFlash(on: _flash),
            if (_countdown != null) PovCountdown(_countdown!),
          ],
        ),
      ),
    );
  }
}
