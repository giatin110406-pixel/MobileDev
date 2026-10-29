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

/// What the picture may use: enough for a sharp 1080p picture, so a photo cut from it
/// on the other phone is crisp too.
const _maxBitrate = 6000000;

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
  Future<void> _messageQueue = Future.value();

  RTCDataChannel? _channel;

  /// The other phone pressed the shutter: take a photo in this many seconds (0 = now).
  final _go = StreamController<int>.broadcast();
  Stream<int> get onGo => _go.stream;

  @protected
  RTCPeerConnection get pc => _pc!;

  /// Starts listening on the data channel (B creates it, A receives it).
  @protected
  void wire(RTCDataChannel channel) {
    _channel = channel;
    channel.onMessage = (message) {
      try {
        final data = jsonDecode(message.text);
        if (data is! Map) return;
        if (data['t'] == 'go') {
          _go.add((data['s'] as num?)?.toInt() ?? 0);
        } else {
          onChannelMessage(Map<String, dynamic>.from(data));
        }
      } catch (_) {
        // Not ours.
      }
    };
  }

  /// A message on the data channel other than `go`.
  @protected
  void onChannelMessage(Map<String, dynamic> data) {}

  @protected
  bool get channelOpen =>
      _channel?.state == RTCDataChannelState.RTCDataChannelOpen;

  @protected
  void sendOnChannel(Map<String, dynamic> data) {
    if (!channelOpen) return;
    _channel!.send(RTCDataChannelMessage(jsonEncode(data)));
  }

  /// The shutter was pressed here: the other phone takes its photo too, after
  /// [seconds] (the timer; 0 for now).
  void sendGo(int seconds) => sendOnChannel({'t': 'go', 's': seconds});

  @protected
  Future<RTCPeerConnection> open() async {
    final connection = await createPeerConnection(_configuration(ice));
    _pc = connection;
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send({'t': PovMsg.ice, 'c': candidate.toMap()});
    };
    connection.onConnectionState = _onState;
    return connection;
  }

  /// Start processing only after the peer and its tracks/handlers are ready.
  /// SDP and ICE operations must be applied in the order they arrive.
  @protected
  void listen() {
    _messages = signal.messages.listen((message) {
      _messageQueue = _messageQueue.then((_) => _receive(message));
    });
  }

  @protected
  void startTimeout() {
    _giveUp ??= Timer(povReconnectWindow, () {
      if (!_closed && link.value != PovLink.live) link.value = PovLink.lost;
    });
  }

  void _onState(RTCPeerConnectionState state) {
    if (_closed) return;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _giveUp?.cancel();
        _giveUp = null;
        link.value = PovLink.live;
        onConnected();
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        if (link.value == PovLink.live || link.value == PovLink.connecting) {
          link.value = PovLink.reconnecting;
        }
        startTimeout();
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

  @protected
  void onConnected() {}

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
    // `t` is our protocol discriminator. The transport's outer `type` may be
    // "broadcast" on older clients; never pass that to the native SDP parser.
    final type = message['t'];
    if (type != PovMsg.offer && type != PovMsg.answer) {
      throw const FormatException('Invalid POV session description');
    }
    await pc.setRemoteDescription(
      RTCSessionDescription(message['sdp'] as String?, type as String),
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
    await _messageQueue;
    await beforeClose();
    await _pc?.close();
    _pc = null;
    await signal.close();
    await _bye.close();
    await _go.close();
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

  /// What A asks of B's camera ('flip', 'torch').
  final _commands = StreamController<String>.broadcast();
  Stream<String> get onCommand => _commands.stream;

  /// How B's camera is set now, sent again once the channel opens.
  bool _front = false;
  bool _torch = false;

  Future<void> start() async {
    final connection = await open();
    for (final track in camera.getTracks()) {
      await connection.addTrack(track, camera);
    }
    wire(
      await connection.createDataChannel(
        'pov',
        RTCDataChannelInit()..ordered = true,
      ),
    );
    _channel!.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) _sendState();
    };
    listen();
    await signal.ready;
    startTimeout();
  }

  @override
  Future<void> onMessage(Map<String, dynamic> message) async {
    switch (message['t']) {
      case PovMsg.ready:
        await _offer();
      case PovMsg.answer:
        if (pc.signalingState ==
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          await setRemote(message);
        }
    }
  }

  /// A is waiting: send the camera. Again (restarting the connection) when A asks
  /// once more, because the picture dropped.
  Future<void> _offer() async {
    final state = pc.signalingState;
    if (state == RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
        (_remoteSet && link.value != PovLink.reconnecting)) {
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

  /// Tells A how B's camera is set (which side, whether the light is on).
  void sendState({required bool front, required bool torch}) {
    _front = front;
    _torch = torch;
    _sendState();
  }

  void _sendState() =>
      sendOnChannel({'t': 'state', 'front': _front, 'torch': _torch});

  @override
  void onChannelMessage(Map<String, dynamic> data) {
    if (data['t'] == 'cmd' && data['c'] is String) {
      _commands.add(data['c'] as String);
    }
  }

  @override
  Future<void> beforeClose() async {
    await _commands.close();
  }

  /// A photo was taken: A's screen flashes.
  void sendShot(int count) => sendOnChannel({'t': 'shot', 'n': count});
}

/// A's end: receives B's camera.
class PovViewerConnection extends _PovConnection {
  PovViewerConnection({required super.signal, required super.ice});

  /// B's picture, once it arrives.
  final remoteStream = ValueNotifier<MediaStream?>(null);

  final _shots = StreamController<int>.broadcast();

  /// B took a photo: how many so far.
  Stream<int> get onShot => _shots.stream;

  /// B's camera settings changed: (front, torch).
  final _states = StreamController<(bool, bool)>.broadcast();
  Stream<(bool, bool)> get onState => _states.stream;

  Timer? _ask;
  String? _lastOffer;
  RTCSessionDescription? _lastAnswer;

  Future<void> start() async {
    final connection = await open();
    connection.onTrack = (event) {
      if (event.track.kind != 'video') return;
      if (event.streams.isNotEmpty) remoteStream.value = event.streams.first;
    };
    connection.onDataChannel = wire;
    listen();
    await signal.ready;
    startTimeout();
    _askForOffer();
  }

  /// Asks B's camera to do something: 'flip' (the other camera) or 'torch' (the light).
  void sendCommand(String command) => sendOnChannel({'t': 'cmd', 'c': command});

  @override
  void onChannelMessage(Map<String, dynamic> data) {
    if (data['t'] == 'shot') {
      _shots.add((data['n'] as num?)?.toInt() ?? 0);
    } else if (data['t'] == 'state') {
      _states.add((data['front'] == true, data['torch'] == true));
    }
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
  void onConnected() {
    _ask?.cancel();
  }

  @override
  void onDropped() {
    if (_ask == null || !_ask!.isActive) _askForOffer();
  }

  @override
  Future<void> onMessage(Map<String, dynamic> message) async {
    if (message['t'] != PovMsg.offer) return;
    final sdp = message['sdp'] as String?;
    if (sdp != null && sdp == _lastOffer && _lastAnswer != null) {
      send({
        't': PovMsg.answer,
        'sdp': _lastAnswer!.sdp,
        'type': _lastAnswer!.type,
      });
      return;
    }
    _remoteSet = false;
    await setRemote(message);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _lastOffer = sdp;
    _lastAnswer = answer;
    send({'t': PovMsg.answer, 'sdp': answer.sdp, 'type': answer.type});
  }

  @override
  Future<void> beforeClose() async {
    _ask?.cancel();
    await _shots.close();
    await _states.close();
    remoteStream.dispose();
  }
}
