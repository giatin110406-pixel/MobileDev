import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_preview.dart';

/// A picture the camera just took.
@immutable
class ShotPicture {
  const ShotPicture({
    required this.path,
    this.shotId,
    this.expectsBurst = false,
  });

  /// The JPEG (its EXIF says how to turn it upright).
  final String path;

  /// Set when the camera keeps files for this shot; they are let go with
  /// [ShotCamera.releaseShot].
  final String? shotId;

  /// The frames around this shot will follow on [ShotCamera.bursts].
  final bool expectsBurst;
}

/// The frames the camera kept around the shot [shotId].
@immutable
class ShotBurst {
  const ShotBurst({required this.shotId, required this.frames});

  final String shotId;
  final List<RewindFrame> frames;
}

/// The camera of the camera page. On Android it is the Kotlin camera that
/// keeps the last seconds of frames for every shot; elsewhere (and in tests)
/// it is the camera plugin, which keeps none.
abstract class ShotCamera {
  bool get isInitialized;

  /// The lens's zoom ratios, known once initialised.
  double get minZoom;
  double get maxZoom;

  /// Throws a [CameraException] (`CameraAccessDenied` when the permission is
  /// refused).
  Future<void> initialize();
  Future<void> dispose();

  /// The live picture, filling the square it is put in (centre-cropped).
  Widget buildPreview();
  Future<void> setFlashMode(FlashMode mode);
  Future<void> setZoomLevel(double level);
  Future<ShotPicture> takePicture();
  Future<void> startVideoRecording();

  /// The path of the MP4.
  Future<String> stopVideoRecording();

  /// Frames kept around shots that came back with a [ShotPicture.shotId].
  Stream<ShotBurst> get bursts;

  /// Codes of errors the camera reports after it started (it stopped working
  /// while the page was open).
  Stream<String> get errors;

  /// The shot's frames and still are not needed any more.
  Future<void> releaseShot(String shotId);

  /// Whether this camera keeps frames around shots at all.
  bool get keepsFrames;

  /// Whether QR codes can be read from this camera's frames (Omni POV).
  bool get canScanCodes;

  /// The raw text of the QR codes in view, while [setCodeScanning] is on.
  Stream<String> get scannedCodes;

  Future<void> setCodeScanning(bool on);
}

/// The camera plugin's own controller: no frames kept.
class PluginShotCamera implements ShotCamera {
  PluginShotCamera(CameraDescription description)
    : _controller = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );

  final CameraController _controller;
  double _minZoom = 1;
  double _maxZoom = 1;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  double get minZoom => _minZoom;

  @override
  double get maxZoom => _maxZoom;

  @override
  bool get keepsFrames => false;

  @override
  bool get canScanCodes => false;

  @override
  Stream<String> get scannedCodes => const Stream<String>.empty();

  @override
  Future<void> setCodeScanning(bool on) async {}

  @override
  Stream<ShotBurst> get bursts => const Stream<ShotBurst>.empty();

  @override
  Stream<String> get errors => const Stream<String>.empty();

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    try {
      _minZoom = await _controller.getMinZoomLevel();
      _maxZoom = await _controller.getMaxZoomLevel();
    } catch (_) {
      // No zoom on this camera: the buttons stay hidden.
    }
  }

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Widget buildPreview() {
    final orientation = _controller.value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    final aspect = landscape
        ? _controller.value.aspectRatio
        : 1 / _controller.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1000 * aspect,
        height: 1000,
        child: CameraPreview(_controller),
      ),
    );
  }

  @override
  Future<void> setFlashMode(FlashMode mode) => _controller.setFlashMode(mode);

  @override
  Future<void> setZoomLevel(double level) => _controller.setZoomLevel(level);

  @override
  Future<ShotPicture> takePicture() async =>
      ShotPicture(path: (await _controller.takePicture()).path);

  @override
  Future<void> startVideoRecording() => _controller.startVideoRecording();

  @override
  Future<String> stopVideoRecording() async =>
      (await _controller.stopVideoRecording()).path;

  @override
  Future<void> releaseShot(String shotId) async {}
}

/// The Kotlin camera (CameraX): every shot comes with the frames before and
/// after it, kept for the person to pick another one.
class NativeShotCamera implements ShotCamera {
  NativeShotCamera({required this.front, RewindBackend? backend})
    : _backend = backend ?? MethodChannelRewindBackend();

  final bool front;
  final RewindBackend _backend;
  RewindStart? _start;
  StreamSubscription<RewindEvent>? _events;
  final _bursts = StreamController<ShotBurst>.broadcast();
  final _errors = StreamController<String>.broadcast();

  @override
  bool get isInitialized => _start != null;

  @override
  double get minZoom => _start?.minZoom ?? 1;

  @override
  double get maxZoom => _start?.maxZoom ?? 1;

  @override
  bool get keepsFrames => true;

  /// Only the main (back) camera reads codes: a mirrored front image would not.
  @override
  bool get canScanCodes => !front;

  final _codes = StreamController<String>.broadcast();

  @override
  Stream<String> get scannedCodes => _codes.stream;

  @override
  Future<void> setCodeScanning(bool on) async {
    if (_start == null) return;
    await _backend.setScanning(on);
  }

  @override
  Stream<ShotBurst> get bursts => _bursts.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<void> initialize() async {
    _events = _backend.events.listen((event) {
      if (event is RewindBurst) {
        _bursts.add(ShotBurst(shotId: event.shotId, frames: event.frames));
      } else if (event is RewindError) {
        _errors.add(event.code);
      } else if (event is RewindCode) {
        _codes.add(event.value);
      }
    });
    try {
      _start = await _backend.start(
        front: front,
        continuous: true,
        askPermission: true,
      );
    } on PlatformException catch (error) {
      await _events?.cancel();
      _events = null;
      throw CameraException(
        error.code == 'noPermission' ? 'CameraAccessDenied' : error.code,
        error.message,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _start = null;
    await _events?.cancel();
    _events = null;
    await _backend.stop();
    await _bursts.close();
    await _errors.close();
    await _codes.close();
  }

  @override
  Widget buildPreview() => RewindPreview(start: _start!);

  @override
  Future<void> setFlashMode(FlashMode mode) => _backend.setFlash(switch (mode) {
    FlashMode.auto => 'auto',
    FlashMode.always => 'on',
    _ => 'off',
  });

  @override
  Future<void> setZoomLevel(double level) => _backend.setZoom(level);

  @override
  Future<ShotPicture> takePicture() async {
    final shot = await _backend.shoot();
    return ShotPicture(
      path: shot.path,
      shotId: shot.shotId,
      expectsBurst: shot.withBurst,
    );
  }

  @override
  Future<void> startVideoRecording() => _backend.startVideo();

  @override
  Future<String> stopVideoRecording() => _backend.stopVideo();

  @override
  Future<void> releaseShot(String shotId) => _backend.releaseShot(shotId);
}
