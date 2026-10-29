import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/pov/pov_connection.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Omni POV, watching: I am the one being photographed, and this shows what my friend's
/// camera sees, as the square the photo will have. Only the friend takes photos; here a
/// flash and a line tell me one was taken. Closes when either of us ends the session.
class PovViewerScreen extends StatefulWidget {
  const PovViewerScreen({
    required this.store,
    required this.repository,
    required this.friend,
    super.key,
  });

  final PovStore store;
  final PovRepository repository;

  /// The friend whose camera it is (null when not known).
  final PocketFriend? friend;

  @override
  State<PovViewerScreen> createState() => _PovViewerScreenState();
}

class _PovViewerScreenState extends State<PovViewerScreen>
    with WidgetsBindingObserver {
  final _renderer = RTCVideoRenderer();
  PovViewerConnection? _connection;
  bool _hasPicture = false;
  bool _flash = false;
  int _shots = 0;
  bool _leaving = false;
  Timer? _awayTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStore);
    _shots = widget.store.session?.shots ?? 0;
    unawaited(_open());
  }

  Future<void> _open() async {
    final session = widget.store.session;
    if (session == null) return;
    try {
      await _renderer.initialize();
      final ice = await widget.repository.iceServers();
      final connection = PovViewerConnection(
        signal: widget.repository.openSignal(session.id),
        ice: ice,
      );
      _connection = connection;
      connection.remoteStream.addListener(() {
        _renderer.srcObject = connection.remoteStream.value;
        if (mounted) {
          setState(() => _hasPicture = connection.remoteStream.value != null);
        }
      });
      connection.link.addListener(_onLink);
      connection.onBye.listen((_) => _finish(PovEnd.ended));
      connection.onShot.listen(_onShot);
      await connection.start();
    } catch (error, stack) {
      AppLog.warn('pov_viewer', error, stack);
      _finish(PovEnd.lostConnection);
    }
  }

  void _onLink() {
    if (!mounted) return;
    if (_connection?.link.value == PovLink.lost) {
      _finish(PovEnd.lostConnection);
    } else {
      setState(() {});
    }
  }

  void _onShot(int count) {
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      _flash = true;
      if (count > _shots) _shots = count;
    });
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  void _onStore() {
    if (!mounted) return;
    final session = widget.store.session;
    if (session == null) {
      _close();
      return;
    }
    if (session.shots > _shots) setState(() => _shots = session.shots);
  }

  /// The session is over: tell the store (with [reason] when the phones lost each
  /// other) and leave.
  void _finish(PovEnd reason) {
    if (_leaving) return;
    unawaited(widget.store.end(reason: reason));
    _close();
  }

  void _close() {
    if (_leaving) return;
    _leaving = true;
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Away from the app for too long: the session is given up.
    if (state == AppLifecycleState.paused) {
      _awayTimer ??= Timer(povReconnectWindow, () => _finish(PovEnd.ended));
    } else if (state == AppLifecycleState.resumed) {
      _awayTimer?.cancel();
      _awayTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStore);
    _awayTimer?.cancel();
    _flashTimer?.cancel();
    final connection = _connection;
    if (connection != null) {
      connection.link.removeListener(_onLink);
      unawaited(connection.close());
    }
    _renderer.srcObject = null;
    unawaited(_renderer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (widget.friend?.name ?? '').toUpperCase();
    final link = _connection?.link.value ?? PovLink.connecting;
    final (label, color) = switch (link) {
      PovLink.live when _hasPicture => (l10n.povLive, NeoColors.lime),
      PovLink.reconnecting => (l10n.povReconnecting, NeoColors.accent),
      PovLink.lost => (l10n.povConnectionLost, NeoColors.coral),
      _ => (l10n.povReconnecting, NeoColors.accent),
    };
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
                      tooltip: l10n.povStopWatching,
                      onPressed: () => _finish(PovEnd.ended),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.povViewerTitle(name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontFamily: NeoFont.display,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NeoLabel(
                      label,
                      color: color,
                      icon: link == PovLink.live && _hasPicture
                          ? Icons.circle
                          : Icons.sync,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Exactly the square the photo will have: a centred 1:1 crop.
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: NeoTheme.panel(
                      color: NeoColors.ink,
                      radius: 28,
                    ),
                    foregroundDecoration: neoPanelOutline(radius: 28),
                    child: NeoPanelClip(
                      radius: 28,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_hasPicture)
                            RTCVideoView(
                              _renderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  l10n.povWaitingPicture(
                                    widget.friend?.name ?? '',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: NeoColors.paper,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: _flash ? 0.85 : 0,
                              duration: const Duration(milliseconds: 160),
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _flash
                      ? NeoLabel(
                          l10n.povSnap(widget.friend?.name.toUpperCase() ?? ''),
                          key: const ValueKey('snap'),
                          color: NeoColors.accent,
                          icon: Icons.camera_alt_outlined,
                        )
                      : Text(
                          l10n.povFramingNote,
                          key: const ValueKey('note'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.povShotsTaken(_shots),
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                NeoButton(
                  expand: true,
                  label: l10n.povStopWatching,
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
}
