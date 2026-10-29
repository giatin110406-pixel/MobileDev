import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';

/// How the picture between the two phones is doing.
enum PovLink {
  /// Setting up.
  connecting,

  /// The picture is coming through.
  live,

  /// It dropped; trying to get it back.
  reconnecting,

  /// It did not come back in time.
  lost,
}

/// The messages the two phones send each other on the private channel, in `t`:
///  * `ready`  A (the viewer) is there and waiting for an offer (sent again every
///    2 seconds until one comes, and again when the picture drops);
///  * `offer`  B's camera, as a session description; `answer` is A's reply;
///  * `ice`    a way to reach the sender (a candidate);
///  * `bye`    the sender is leaving.
abstract final class PovMsg {
  static const ready = 'ready';
  static const offer = 'offer';
  static const answer = 'answer';
  static const ice = 'ice';
  static const bye = 'bye';
}

/// How long the picture may be gone before the session is given up.
const povReconnectWindow = Duration(seconds: 15);

/// Roughly what the picture may use: enough for a sharp 1080p preview.
const _maxBitrate = 1500000;

Map<String, dynamic> _configuration(PovIce ice) => {
  'iceServers': ice.servers,
  'sdpSemantics': 'unified-plan',
  'bundlePolicy': 'max-bundle',
};

/// Both ends: the peer connection and the messages around it.
abstract class _PovConnection {
  _PovConnection({required this.signal, required this.ice});

  final PovSignalChannel signal;
  final PovIce ice;

  /// How the picture is doing.
  final link = ValueNotifier<PovLink>(PovLink.connecting);

  /// The other phone said goodbye.
  final _bye = StreamController<void>.broadcast();
  Stream<void> get onBye => _bye.stream;

  RTCPeerConnection? _pc;
  StreamSubscription<Map<String, dynamic>>? _messages;
  final _pendingCandidates = <RTCIceCandidate>[];
  bool _remoteSet = false;
  Timer? _giveUp;
  bool _closed = false;

  @protected
  RTCPeerConnection get pc => _pc!;

  @protected
  Future<RTCPeerConnection> open() async {
    final connection = await createPeerConnection(_configuration(ice));
    _pc = connection;
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send({'t': PovMsg.ice, 'c': candidate.toMap()});
    };
    connection.onConnectionState = _onState;
    _messages = signal.messages.listen(
      (message) => unawaited(_receive(message)),
    );
    return connection;
  }

  void _onState(RTCPeerConnectionState state) {
    if (_closed) return;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _giveUp?.cancel();
        _giveUp = null;
        link.value = PovLink.live;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        if (link.value == PovLink.live || link.value == PovLink.connecting) {
          link.value = PovLink.reconnecting;
        }
        _giveUp ??= Timer(povReconnectWindow, () {
          if (!_closed && link.value != PovLink.live) link.value = PovLink.lost;
        });
        onDropped();
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        break;
      default:
        break;
    }
  }

  /// The picture dropped: the viewer asks for a new offer.
  @protected
  void onDropped() {}

  Future<void> _receive(Map<String, dynamic> message) async {
    if (_closed) return;
    try {
      switch (message['t']) {
        case PovMsg.ice:
          final c = message['c'];
          if (c is! Map) return;
          final candidate = RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            (c['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_remoteSet) {
            await pc.addCandidate(candidate);
          } else {
            _pendingCandidates.add(candidate);
          }
        case PovMsg.bye:
          _bye.add(null);
        default:
          await onMessage(message);
      }
    } catch (error, stack) {
      AppLog.warn('pov_connection', error, stack);
    }
  }

  @protected
  Future<void> onMessage(Map<String, dynamic> message);

  /// The other phone's description is in: candidates that came early can go in too.
  @protected
  Future<void> remoteDescriptionSet() async {
    _remoteSet = true;
    final early = List.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in early) {
      await pc.addCandidate(candidate);
    }
  }

  @protected
  Future<void> setRemote(Map<String, dynamic> message) async {
    await pc.setRemoteDescription(
      RTCSessionDescription(
        message['sdp'] as String?,
        message['type'] as String?,
      ),
    );
    await remoteDescriptionSet();
  }

  void _send(Map<String, dynamic> message) {
    if (_closed) return;
    signal.send(message).catchError((Object error, StackTrace stack) {
      AppLog.warn('pov_connection', error, stack);
    });
  }

  @protected
  void send(Map<String, dynamic> message) => _send(message);

  /// Says goodbye (so the other side need not wait for a time-out) and lets go of
  /// everything.
  Future<void> close({bool sayBye = true}) async {
    if (_closed) return;
    if (sayBye) {
      try {
        await signal.send({'t': PovMsg.bye});
      } catch (_) {
        // The channel may already be gone.
      }
    }
    _closed = true;
    _giveUp?.cancel();
    await _messages?.cancel();
    await beforeClose();
    await _pc?.close();
    _pc = null;
    await signal.close();
    await _bye.close();
    link.dispose();
  }

  @protected
  Future<void> beforeClose() async {}
}

/// B's end: sends the camera, and tells A when a photo was taken.
class PovHostConnection extends _PovConnection {
  PovHostConnection({
    required super.signal,
    required super.ice,
    required this.camera,
  });

  /// B's camera.
  final MediaStream camera;
  RTCDataChannel? _channel;

  Future<void> start() async {
    final connection = await open();
    for (final track in camera.getTracks()) {
      await connection.addTrack(track, camera);
    }
    _channel = await connection.createDataChannel(
      'pov',
      RTCDataChannelInit()..ordered = true,
    );
    await signal.ready;
  }

  @override
  Future<void> onMessage(Map<String, dynamic> message) async {
    switch (message['t']) {
      case PovMsg.ready:
        await _offer();
      case PovMsg.answer:
        await setRemote(message);
    }
  }

  /// A is waiting: send the camera. Again (restarting the connection) when A asks
  /// once more, because the picture dropped.
  Future<void> _offer() async {
    final state = pc.signalingState;
    if (state == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      // A has not answered yet: send the same offer again.
      final local = await pc.getLocalDescription();
      if (local != null) {
        send({'t': PovMsg.offer, 'sdp': local.sdp, 'type': local.type});
      }
      return;
    }
    final restart = _remoteSet;
    _remoteSet = false;
    final offer = await pc.createOffer({
      if (restart) 'iceRestart': true,
      'offerToReceiveVideo': false,
      'offerToReceiveAudio': false,
    });
    await pc.setLocalDescription(offer);
    await _limitBitrate();
    send({'t': PovMsg.offer, 'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _limitBitrate() async {
    try {
      for (final sender in await pc.getSenders()) {
        if (sender.track?.kind != 'video') continue;
        final parameters = sender.parameters;
        final encodings = parameters.encodings;
        if (encodings == null || encodings.isEmpty) continue;
        for (final encoding in encodings) {
          encoding.maxBitrate = _maxBitrate;
          encoding.maxFramerate = 30;
        }
        await sender.setParameters(parameters);
      }
    } catch (error, stack) {
      AppLog.warn('pov_connection', error, stack);
    }
  }

  /// A photo was taken: A's screen flashes.
  void sendShot(int count) {
    final channel = _channel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    channel.send(RTCDataChannelMessage(jsonEncode({'t': 'shot', 'n': count})));
  }
}

/// A's end: receives B's camera.
class PovViewerConnection extends _PovConnection {
  PovViewerConnection({required super.signal, required super.ice});

  /// B's picture, once it arrives.
  final remoteStream = ValueNotifier<MediaStream?>(null);

  final _shots = StreamController<int>.broadcast();

  /// B took a photo: how many so far.
  Stream<int> get onShot => _shots.stream;

  Timer? _ask;

  Future<void> start() async {
    final connection = await open();
    connection.onTrack = (event) {
      if (event.track.kind != 'video') return;
      if (event.streams.isNotEmpty) remoteStream.value = event.streams.first;
    };
    connection.onDataChannel = (channel) {
      channel.onMessage = (message) {
        try {
          final data = jsonDecode(message.text);
          if (data is Map && data['t'] == 'shot') {
            _shots.add((data['n'] as num?)?.toInt() ?? 0);
          }
        } catch (_) {
          // Not ours.
        }
      };
    };
    await signal.ready;
    _askForOffer();
  }

  /// B does not know A is here until A says so. Say it now, and again every 2
  /// seconds until the offer comes.
  void _askForOffer() {
    _ask?.cancel();
    send({'t': PovMsg.ready});
    _ask = Timer.periodic(const Duration(seconds: 2), (_) {
      send({'t': PovMsg.ready});
    });
  }

  @override
  void onDropped() {
    if (_ask == null || !_ask!.isActive) _askForOffer();
  }

  @override
  Future<void> onMessage(Map<String, dynamic> message) async {
    if (message['t'] != PovMsg.offer) return;
    _remoteSet = false;
    await setRemote(message);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    send({'t': PovMsg.answer, 'sdp': answer.sdp, 'type': answer.type});
    _ask?.cancel();
  }

  @override
  Future<void> beforeClose() async {
    _ask?.cancel();
    await _shots.close();
    remoteStream.dispose();
  }
}
