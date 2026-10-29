// Run on a phone to check real camera -> WebRTC -> decoded remote frames:
// flutter run -d <device> -t test/tools_device/pov_live_video_probe.dart
// This uses no account and never takes or saves a photo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:neo_brutalism_locket/features/pov/pov_connection.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_signaling.dart';

class _Wire implements PovSignalChannel {
  final incoming = StreamController<Map<String, dynamic>>.broadcast();
  late _Wire other;

  @override
  Stream<Map<String, dynamic>> get messages => incoming.stream;
  @override
  Future<void> get ready => Future.value();
  @override
  Future<void> send(Map<String, dynamic> message) async {
    // Emulate the SDK's reserved fields around the actual application payload.
    final wire = encodePovSignal(message)
      ..['type'] = 'broadcast'
      ..['event'] = 'signal';
    final received = decodePovSignal(wire);
    if (received != null && !other.incoming.isClosed) {
      other.incoming.add(received);
    }
  }

  @override
  Future<void> close() => incoming.close();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final renderer = RTCVideoRenderer();
  String status = 'Opening camera and live video connection…';
  late StateSetter update;
  runApp(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(status),
                  ),
                  Expanded(child: RTCVideoView(renderer)),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  MediaStream? camera;
  PovHostConnection? host;
  PovViewerConnection? viewer;
  try {
    await renderer.initialize();
    camera = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {'facingMode': 'environment', 'width': 640, 'height': 480},
    });
    final hostWire = _Wire();
    final viewerWire = _Wire();
    hostWire.other = viewerWire;
    viewerWire.other = hostWire;
    const ice = PovIce(servers: [], hasRelay: false);
    host = PovHostConnection(signal: hostWire, ice: ice, camera: camera);
    viewer = PovViewerConnection(signal: viewerWire, ice: ice);
    final remote = Completer<MediaStream>();
    viewer.remoteStream.addListener(() {
      final stream = viewer!.remoteStream.value;
      if (stream != null && !remote.isCompleted) remote.complete(stream);
    });
    var shots = 0;
    viewer.onShot.listen((_) => shots++);
    await host.start();
    await viewer.start();
    final stream = await remote.future.timeout(const Duration(seconds: 15));
    renderer.srcObject = stream;
    final track = stream.getVideoTracks().single;
    // Each captureFrame waits for a new decoded remote video frame.
    final first = await track.captureFrame().timeout(
      const Duration(seconds: 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 750));
    final second = await track.captureFrame().timeout(
      const Duration(seconds: 10),
    );
    if (first.lengthInBytes == 0 ||
        second.lengthInBytes == 0 ||
        shots != 0 ||
        viewer.link.value != PovLink.live) {
      throw StateError('No continuous remote video before the shutter');
    }
    status =
        'POV_VIDEO_PASS: two decoded remote frames '
        '(${first.lengthInBytes}, ${second.lengthInBytes} bytes), 0 photos taken';
    debugPrint(status);
    update(() {});
    await Future<void>.delayed(const Duration(seconds: 2));
  } catch (error, stack) {
    status = 'POV_VIDEO_FAIL: $error';
    debugPrint('$status\n$stack');
    update(() {});
  } finally {
    renderer.srcObject = null;
    await host?.close(sayBye: false);
    await viewer?.close(sayBye: false);
    if (camera != null) {
      for (final track in camera.getTracks()) {
        await track.stop();
      }
      await camera.dispose();
    }
    await renderer.dispose();
  }
}
