import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neo_brutalism_locket/app/pocket_top_bar.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/before_after_view.dart';
import 'package:neo_brutalism_locket/features/camera/capture_options.dart';
import 'package:neo_brutalism_locket/features/camera/style_pill.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/server_settings_sheet.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/photos/archive_screen.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/quest/quest_verifier.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The SHOOT tab: live camera, the print being styled, and quest mode. The
/// app shell keeps it alive across tabs so the camera does not restart.
class CameraTab extends StatefulWidget {
  const CameraTab({
    super.key,
    required this.player,
    required this.photos,
    required this.repository,
    required this.styleEngineFactory,
    required this.questVerifier,
    required this.onPhotoChanged,
    required this.onOpenFeed,
    required this.onOpenArchive,
    required this.onOpenQuestSheet,
    required this.onQuestPassed,
    this.onSendPrint,
    this.onPhotoRemoved,
    this.onVideoRecorded,
  });

  final PlayerStore player;

  /// Prints on this device, newest first (owned by the shell).
  final List<NeoPhoto> photos;
  final PhotoRepository repository;
  final StyleEngineFactory styleEngineFactory;
  final QuestVerifier questVerifier;

  /// A print was created or changed (saved already).
  final ValueChanged<NeoPhoto> onPhotoChanged;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenArchive;
  final VoidCallback onOpenQuestSheet;

  /// Today's quest photo passed the check: style, caption and post it.
  final Future<void> Function(Quest quest, NeoPhoto photo, int day)
  onQuestPassed;

  /// Post this shot (to all friends or some). True when it was sent or
  /// queued; the shot is then removed from this phone. Null without an
  /// account: shots are kept on the phone instead.
  final Future<bool> Function(NeoPhoto photo)? onSendPrint;

  /// A shot was thrown away or posted and is no longer on this phone.
  final ValueChanged<NeoPhoto>? onPhotoRemoved;

  /// A clip was recorded (hold the shutter). Null without an account: there
  /// is nowhere to keep videos on the phone, so recording is off.
  final Future<void> Function(File video)? onVideoRecorded;

  @override
  State<CameraTab> createState() => CameraTabState();
}

class CameraTabState extends State<CameraTab> {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  NeoPhoto? _activePhoto;
  FlashMode _flashMode = FlashMode.off;
  StyleType _selectedStyleType = StyleType.pixel8bit;
  String? _cameraMessage;
  int _cameraIndex = 0;
  bool _cameraLoading = true;
  bool _processing = false;
  bool _showOriginal = false;
  bool _showPrint = false;
  String _progressStage = '';
  double _progress = 0;

  // Zoom: the lens limits, the current level, and the level a pinch began at.
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtPinchStart = 1;

  // Self-timer: seconds left while counting down.
  ShotTimer _shotTimer = ShotTimer.off;
  int? _countdown;
  Timer? _countdownTimer;

  // Video: recording while the shutter is held (up to [maxVideoLength]).
  bool _recording = false;
  DateTime? _recordStart;
  Timer? _recordTimer;

  /// The quest being shot, while the camera is in quest mode (camera only,
  /// style locked, every miss costs a try).
  Quest? _questModeQuest;
  bool _checkingQuest = false;

  bool get _questMode => _questModeQuest != null;

  /// Shots thrown away while their style was still being applied.
  final Set<String> _discarded = {};

  /// The shot just taken, with an account: a draft to post or throw away
  /// (an older print opened from the history is not a draft).
  String? _draftId;

  bool get _draftMode =>
      widget.onSendPrint != null &&
      _draftId != null &&
      _activePhoto?.id == _draftId;

  /// Taking, checking or styling a photo right now.
  bool get busy => _processing;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  /// Enters quest mode for [quest] (back on the live camera).
  void startQuest(Quest quest) {
    setState(() {
      _questModeQuest = quest;
      _showPrint = false;
    });
  }

  /// Leaves quest mode unless a quest photo is being checked.
  void leaveQuestMode() {
    if (_questMode && !_checkingQuest) setState(() => _questModeQuest = null);
  }

  /// 00:00 in Vietnam: yesterday's quest mode ends.
  void onNewDay() {
    if (_questMode && !_checkingQuest) {
      setState(() => _questModeQuest = null);
      _notify('ĐÃ SANG NGÀY MỚI · CÓ NHIỆM VỤ MỚI!');
    }
  }

  /// Shows [photo] as the active print.
  void openPhoto(NeoPhoto photo) {
    setState(() {
      if (photo.id != _draftId) _draftId = null;
      _activePhoto = photo;
      _selectedStyleType = photo.styleType ?? StyleType.pixel8bit;
      _showPrint = true;
      _showOriginal = photo.status != ProcessingStatus.done;
    });
  }

  /// Back to the live camera. A draft stays on screen until it is posted
  /// or thrown away.
  void closePrint() {
    if (_showPrint && !_draftMode) setState(() => _showPrint = false);
  }

  /// HỦY: the shot is deleted and the camera is back.
  void _discardPrint(NeoPhoto photo) => _removeShot(photo);

  /// ĐĂNG: pick who gets it; once sent (or queued) the draft goes away.
  Future<void> _postPrint(NeoPhoto photo) async {
    final send = widget.onSendPrint;
    if (send == null) return;
    final posted = await send(photo);
    if (posted && mounted) _removeShot(photo);
  }

  void _removeShot(NeoPhoto photo) {
    _discarded.add(photo.id);
    if (_draftId == photo.id) _draftId = null;
    setState(() {
      _showPrint = false;
      if (_activePhoto?.id == photo.id) _activePhoto = null;
      _processing = false;
    });
    widget.onPhotoRemoved?.call(photo);
    widget.repository.delete(photo).catchError((Object _) {});
  }

  void _notify(String message) => showNeoSnack(context, message);

  @override
  Widget build(BuildContext context) {
    final showPrint = _showPrint && _activePhoto != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: showPrint
          ? _buildPrint(_activePhoto!, key: const ValueKey('print'))
          : _buildCamera(key: const ValueKey('camera')),
    );
  }

  Future<void> _showOutOfTries() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: NeoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      title: const Text(
        'HẾT LƯỢT HÔM NAY',
        style: TextStyle(color: NeoColors.ink, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'Không đúng. Bạn đã dùng hết 3 lượt thử hôm nay. Nhiệm vụ mới sẽ đến lúc 00:00.',
        style: TextStyle(color: NeoColors.ink),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  /// Takes the photo for today's quest: checks it shows the subject, and on a
  /// match moves on to styling and posting. A miss costs one of today's tries.
  Future<void> _captureQuest() async {
    final camera = _camera;
    final quest = _questModeQuest;
    if (camera == null ||
        !camera.value.isInitialized ||
        _processing ||
        quest == null) {
      return;
    }
    if (widget.player.todayQuest?.id != quest.id) {
      setState(() => _questModeQuest = null);
      _notify('ĐÃ SANG NGÀY MỚI · CÓ NHIỆM VỤ MỚI!');
      return;
    }
    setState(() {
      _processing = true;
      _checkingQuest = true;
    });
    try {
      final day = widget.player.today;
      final shot = await camera.takePicture();
      final bytes = await compute(cropToSquareJpeg, await shot.readAsBytes());
      final bool match;
      try {
        match = await widget.questVerifier.check(bytes, quest);
      } on QuestCheckUnavailable catch (error) {
        _notify(error.message.toUpperCase());
        return;
      }
      if (!match) {
        await widget.player.recordFailedAttempt();
        final left = widget.player.attemptsLeft;
        if (left == 0) {
          if (mounted) setState(() => _questModeQuest = null);
          await _showOutOfTries();
        } else {
          _notify('KHÔNG ĐÚNG · CÒN $left LƯỢT THỬ');
        }
        return;
      }
      final photo = await widget.repository.saveOriginal(
        bytes,
        styleType: quest.style,
      );
      await widget.player.recordPassed(photo.id);
      if (!mounted) return;
      widget.onPhotoChanged(photo);
      setState(() => _questModeQuest = null);
      await widget.onQuestPassed(quest, photo, day);
    } on PlayerException catch (error) {
      if (mounted) setState(() => _questModeQuest = null);
      _notify(error.message.toUpperCase());
    } catch (_) {
      _notify('PHOTO DID NOT SAVE. TRY AGAIN.');
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _checkingQuest = false;
        });
      }
    }
  }

  Future<void> _initializeCamera({int? index}) async {
    if (mounted) {
      setState(() {
        _cameraLoading = true;
        _cameraMessage = null;
      });
    }
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available');
      }
      final nextIndex = index ?? _cameraIndex;
      final oldCamera = _camera;
      _camera = null;
      await oldCamera?.dispose();
      final nextCamera = CameraController(
        _cameras[nextIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      _camera = nextCamera;
      await nextCamera.initialize();
      await nextCamera.setFlashMode(_flashMode);
      double minZoom = 1;
      double maxZoom = 1;
      try {
        minZoom = await nextCamera.getMinZoomLevel();
        maxZoom = await nextCamera.getMaxZoomLevel();
      } catch (_) {
        // No zoom on this camera: the buttons stay hidden.
      }
      if (!mounted) return;
      setState(() {
        _cameraIndex = nextIndex;
        _cameraLoading = false;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = clampZoom(1, minZoom, maxZoom);
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraMessage = error.code == 'CameraAccessDenied'
            ? 'CAMERA ACCESS IS OFF'
            : 'CAMERA IS NOT AVAILABLE';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraMessage = 'CAMERA IS NOT AVAILABLE';
      });
    }
  }

  /// Shutter tap: starts the self-timer if one is set (a second tap cancels
  /// it), otherwise shoots now.
  Future<void> _capture() async {
    if (_recording) return;
    if (_countdown != null) {
      _cancelCountdown();
      return;
    }
    if (_shotTimer != ShotTimer.off) {
      _startCountdown();
      return;
    }
    await _shoot();
  }

  void _startCountdown() {
    setState(() => _countdown = _shotTimer.seconds);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (_countdown ?? 1) - 1;
      if (left <= 0) {
        timer.cancel();
        if (!mounted) return;
        setState(() => _countdown = null);
        _shoot();
      } else if (mounted) {
        setState(() => _countdown = left);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (mounted) setState(() => _countdown = null);
  }

  Future<void> _setZoom(double level) async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final next = clampZoom(level, _minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.01) return;
    setState(() => _zoom = next);
    try {
      await camera.setZoomLevel(next);
    } catch (_) {
      // Some lenses refuse a level; the next pinch tries again.
    }
  }

  bool get _canRecord =>
      widget.onVideoRecorded != null &&
      !_questMode &&
      !_processing &&
      _countdown == null;

  Future<void> _startVideo() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || !_canRecord) return;
    if (_recording) return;
    final failed = AppLocalizations.of(context).videoFailed;
    try {
      await camera.startVideoRecording();
    } catch (_) {
      _notify(failed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
    });
    _recordTimer = Timer(maxVideoLength, _stopVideo);
  }

  Future<void> _stopVideo() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    final camera = _camera;
    final started = _recordStart ?? DateTime.now();
    final l10n = AppLocalizations.of(context);
    setState(() => _recording = false);
    if (camera == null) return;
    try {
      final file = await camera.stopVideoRecording();
      final length = DateTime.now().difference(started);
      if (length < const Duration(milliseconds: 600)) {
        _notify(l10n.videoTooShort);
        try {
          await File(file.path).delete();
        } catch (_) {}
        return;
      }
      await widget.onVideoRecorded?.call(File(file.path));
    } catch (_) {
      _notify(l10n.videoFailed);
    }
  }

  Future<void> _shoot() async {
    if (_questMode) return _captureQuest();
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _processing) return;

    setState(() => _processing = true);
    try {
      final shot = await camera.takePicture();
      // Save exactly what the square viewfinder showed: a centred 1:1 crop.
      final bytes = await compute(cropToSquareJpeg, await shot.readAsBytes());
      await _startPrint(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _notify('PHOTO DID NOT SAVE. TRY AGAIN.');
    }
  }

  /// Lets the user pick any photo from the device instead of taking one. The
  /// photo is centre-cropped to the same 1:1 square as a camera shot.
  Future<void> _uploadFromGallery() async {
    if (_processing || _questMode) return;
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() => _processing = true);
      final bytes = await compute(
        cropToSquareJpegCapped,
        await picked.readAsBytes(),
      );
      await _startPrint(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _notify('COULD NOT OPEN THAT PHOTO. TRY ANOTHER.');
    }
  }

  /// Saves square JPEG [bytes] as a new print with the selected style and
  /// starts processing it (shared by camera capture and gallery upload).
  Future<void> _startPrint(Uint8List bytes) async {
    final photo = await widget.repository.saveOriginal(
      bytes,
      styleType: _selectedStyleType,
    );
    if (!mounted) return;
    setState(() {
      _activePhoto = photo;
      _draftId = photo.id;
      _showOriginal = true;
      _showPrint = true;
    });
    widget.onPhotoChanged(photo);
    _processPhoto(photo);
  }

  Future<void> _processPhoto(NeoPhoto photo) async {
    try {
      final styleType = photo.styleType ?? StyleType.pixel8bit;
      final engine = widget.styleEngineFactory.create(styleType);
      if (mounted) {
        setState(() {
          _progressStage = 'starting';
          _progress = 0;
        });
      }
      final output = await engine.process(
        File(photo.originalPath),
        styleType,
        onProgress: (stage, fraction) {
          if (!mounted) return;
          setState(() {
            _progressStage = stage;
            _progress = fraction;
          });
        },
      );
      if (_discarded.contains(photo.id)) {
        try {
          await output.file.delete();
        } catch (_) {}
        return;
      }
      final complete = photo.copyWith(
        processedPath: output.file.path,
        styleSource: output.source,
        status: ProcessingStatus.done,
        clearFailureReason: true,
      );
      if (output.note != null) {
        _notify('FALLBACK USED: ${output.note}');
      }
      await widget.repository.upsert(complete);
      widget.onPhotoChanged(complete);
      if (!mounted) return;
      setState(() {
        _activePhoto = complete;
        _showOriginal = false;
        _processing = false;
      });
    } catch (error) {
      if (_discarded.contains(photo.id)) return;
      final failed = photo.copyWith(
        status: ProcessingStatus.failed,
        failureReason: error.toString(),
      );
      await widget.repository.upsert(failed);
      widget.onPhotoChanged(failed);
      if (!mounted) return;
      setState(() {
        _activePhoto = failed;
        _showOriginal = true;
        _processing = false;
      });
      _notify('STYLE PASS FAILED. ORIGINAL IS SAFE.');
    }
  }

  Future<void> _applyStyleToPhoto(NeoPhoto photo, StyleType styleType) async {
    if (_processing) return;
    if (photo.status == ProcessingStatus.done && photo.styleType == styleType) {
      return;
    }
    final pending = photo.copyWith(
      status: ProcessingStatus.pending,
      styleType: styleType,
      clearFailureReason: true,
    );
    setState(() {
      _selectedStyleType = styleType;
      _activePhoto = pending;
      _showOriginal = true;
      _processing = true;
    });
    await widget.repository.upsert(pending);
    await _processPhoto(pending);
  }

  Future<void> _retryProcessing() async {
    final photo = _activePhoto;
    if (photo == null || _processing) return;
    final pending = photo.copyWith(
      status: ProcessingStatus.pending,
      clearFailureReason: true,
    );
    setState(() {
      _activePhoto = pending;
      _processing = true;
    });
    await widget.repository.upsert(pending);
    await _processPhoto(pending);
  }

  void _setCameraStyle(StyleType styleType) {
    if (_processing) return;
    setState(() => _selectedStyleType = styleType);
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final mode = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await camera.setFlashMode(mode);
      if (mounted) setState(() => _flashMode = mode);
    } catch (_) {
      _notify('FLASH IS NOT AVAILABLE');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _processing) return;
    await _initializeCamera(index: (_cameraIndex + 1) % _cameras.length);
  }

  Widget _buildCamera({required Key key}) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.translucent,
      // Swipe up anywhere on the camera page to see the feed (like Locket).
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -400) widget.onOpenFeed();
      },
      child: _buildCameraBody(),
    );
  }

  Widget _buildCameraBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PocketTopBar(
            actions: [
              NeoIconButton(
                icon: Icons.dns_outlined,
                tooltip: 'Home laptop settings',
                fill: NeoColors.teal,
                onPressed: () => showServerSettingsSheet(context),
              ),
              NeoIconButton(
                icon: _flashMode == FlashMode.off
                    ? Icons.flash_off
                    : Icons.flash_on,
                tooltip: 'Change flash mode',
                fill: NeoColors.yellow,
                onPressed: _toggleFlash,
              ),
              NeoIconButton(
                icon: switch (_shotTimer) {
                  ShotTimer.off => Icons.timer_off_outlined,
                  ShotTimer.three => Icons.timer_3,
                  ShotTimer.ten => Icons.timer_10,
                },
                tooltip: _shotTimer == ShotTimer.off
                    ? AppLocalizations.of(context).timerOff
                    : AppLocalizations.of(
                        context,
                      ).timerSeconds(_shotTimer.seconds),
                fill: _shotTimer == ShotTimer.off
                    ? NeoColors.surface
                    : NeoColors.orange,
                onPressed: _countdown != null || _recording
                    ? null
                    : () => setState(() => _shotTimer = _shotTimer.next),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _questMode
              ? _buildQuestModeHeader(_questModeQuest!)
              : QuestStrip(
                  store: widget.player,
                  onTap: widget.onOpenQuestSheet,
                ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: AspectRatio(aspectRatio: 1, child: _buildViewfinder()),
            ),
          ),
          const SizedBox(height: 10),
          _questMode
              ? Center(
                  child: NeoLabel(
                    'STYLE: ${_questModeQuest!.style.label}',
                    color: questStyleColor(_questModeQuest!.style),
                    icon: Icons.lock_outline,
                  ),
                )
              : _buildStylePill(),
          const SizedBox(height: 16),
          _buildCaptureControls(),
          const SizedBox(height: 6),
          Center(
            child: Semantics(
              button: true,
              label: 'Open feed',
              child: InkWell(
                onTap: widget.onOpenFeed,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 18,
                        color: NeoColors.ink,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'FEED',
                        style: TextStyle(
                          color: NeoColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestModeHeader(Quest quest) {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: NeoTheme.panel(color: questStyleColor(quest.style)),
      child: Row(
        children: [
          Text(quest.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'CHẾ ĐỘ NHIỆM VỤ · CHỈ CHỤP TRỰC TIẾP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NeoColors.ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chụp ${quest.subject}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          AttemptDots(left: widget.player.attemptsLeft),
          const SizedBox(width: 8),
          NeoIconButton(
            icon: Icons.close,
            tooltip: 'Thoát chế độ nhiệm vụ',
            fill: NeoColors.surface,
            onPressed: _processing
                ? null
                : () => setState(() => _questModeQuest = null),
          ),
        ],
      ),
    );
  }

  /// Corner radius of the square (1:1) camera and print frames.
  static const double _squareRadius = 40;

  /// The camera feed scaled to cover the square frame, centre-cropped.
  Widget _squarePreview(CameraController camera) {
    final orientation = camera.value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    final aspect = landscape
        ? camera.value.aspectRatio
        : 1 / camera.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1000 * aspect,
        height: 1000,
        child: CameraPreview(camera),
      ),
    );
  }

  Widget _buildViewfinder() {
    final camera = _camera;
    return Container(
      decoration: NeoTheme.panel(
        color: NeoColors.surface,
        borderWidth: 2,
        radius: _squareRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            GestureDetector(
              onScaleStart: (_) => _zoomAtPinchStart = _zoom,
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                _setZoom(_zoomAtPinchStart * details.scale);
              },
              child: _squarePreview(camera),
            )
          else
            _buildCameraFallback(),
          // Only while something is going on: recording, or checking a quest
          // photo. The viewfinder is otherwise just the picture.
          if (_recording || _checkingQuest)
            Positioned(
              top: 12,
              left: 12,
              child: _recording
                  ? const NeoLabel(
                      'REC',
                      color: NeoColors.pink,
                      icon: Icons.circle,
                    )
                  : const NeoLabel(
                      'ĐANG KIỂM TRA...',
                      color: NeoColors.yellow,
                      icon: Icons.search,
                    ),
            ),
          if (camera != null &&
              camera.value.isInitialized &&
              zoomPresets(_minZoom, _maxZoom).length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(child: _zoomButtons()),
            ),
          if (_countdown != null)
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: NeoTheme.panel(
                  color: NeoColors.yellow,
                  radius: 999,
                ),
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _zoomButtons() {
    final presets = zoomPresets(_minZoom, _maxZoom);
    // The button nearest the current level lights up (pinching in between
    // shows the exact level on it).
    var nearest = presets.first;
    for (final level in presets) {
      if ((level - _zoom).abs() < (nearest - _zoom).abs()) nearest = level;
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: NeoColors.ink.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final level in presets)
            Semantics(
              button: true,
              selected: level == nearest,
              label: 'Zoom ${zoomLabel(level)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setZoom(level),
                // A roomy touch area around a small pill.
                child: SizedBox(
                  width: 36,
                  height: 32,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: level == nearest
                            ? NeoColors.yellow
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        level == nearest ? zoomLabel(_zoom) : zoomLabel(level),
                        style: TextStyle(
                          color: level == nearest
                              ? NeoColors.ink
                              : NeoColors.surface,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The style control right under the photo: one pill, swiped left/right
  /// between NO STYLE, 8-BIT and VAN GOGH. On the camera it sets the style for
  /// the next shot; on a print it re-styles that photo.
  Widget _buildStylePill({NeoPhoto? photo}) {
    return Center(
      child: StylePill(
        value: photo?.styleType ?? _selectedStyleType,
        enabled: !_processing,
        onChanged: (styleType) => photo == null
            ? _setCameraStyle(styleType)
            : _applyStyleToPhoto(photo, styleType),
      ),
    );
  }

  Widget _buildCameraFallback() {
    return ColoredBox(
      color: NeoColors.blue,
      child: Center(
        // Scales down when the square is short (small phones, quest strip).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: NeoTheme.panel(
                    color: NeoColors.yellow,
                    borderWidth: 2,
                    radius: 999,
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: NeoColors.ink,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _cameraLoading
                      ? 'FINDING CAMERA'
                      : _cameraMessage ?? 'CAMERA READY',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ENABLE CAMERA ACCESS TO START SHOOTING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeoColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_cameraLoading) ...[
                  const SizedBox(height: 18),
                  NeoButton(
                    label: 'TRY AGAIN',
                    icon: Icons.refresh,
                    variant: NeoButtonVariant.outline,
                    onPressed: _initializeCamera,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _recentThumb(),
                // Quests must be shot live: no gallery in quest mode.
                if (!_questMode) ...[
                  const SizedBox(width: 10),
                  NeoIconButton(
                    icon: Icons.add_photo_alternate_outlined,
                    tooltip: 'Upload a photo from this device',
                    onPressed: _processing ? null : _uploadFromGallery,
                    fill: NeoColors.pink,
                  ),
                ],
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Take photo',
          hint: widget.onVideoRecorded == null
              ? null
              : AppLocalizations.of(context).holdForVideo,
          child: GestureDetector(
            onTap: _processing ? null : _capture,
            onLongPressStart: _canRecord ? (_) => _startVideo() : null,
            onLongPressEnd: _canRecord || _recording
                ? (_) => _stopVideo()
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _processing ? NeoColors.switchOff : NeoColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: NeoColors.ink, width: 2),
                boxShadow: _processing
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
                  color: _recording ? NeoColors.pink : NeoColors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: NeoColors.surface, width: 2),
                ),
                child: _processing
                    ? const Padding(
                        padding: EdgeInsets.all(17),
                        child: CircularProgressIndicator(
                          color: NeoColors.ink,
                          strokeWidth: 2,
                        ),
                      )
                    : _recording
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: maxVideoLength,
                        builder: (context, value, _) => Padding(
                          padding: const EdgeInsets.all(4),
                          child: CircularProgressIndicator(
                            value: value,
                            color: NeoColors.ink,
                            strokeWidth: 4,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: NeoIconButton(
              icon: Icons.flip_camera_ios_outlined,
              tooltip: 'Switch camera',
              onPressed: _flipCamera,
              fill: NeoColors.purple,
            ),
          ),
        ),
      ],
    );
  }

  Widget _recentThumb() {
    final photo = widget.photos.isEmpty ? null : widget.photos.first;
    return Semantics(
      button: true,
      label: 'Open archive',
      child: GestureDetector(
        onTap: widget.onOpenArchive,
        child: Container(
          width: 46,
          height: 46,
          decoration: NeoTheme.panel(color: NeoColors.teal, borderWidth: 2),
          clipBehavior: Clip.antiAlias,
          child: photo == null
              ? const Icon(
                  Icons.collections_outlined,
                  color: NeoColors.ink,
                  size: 22,
                )
              : Image.file(
                  File(photo.processedPath ?? photo.originalPath),
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }

  Widget _buildPrint(NeoPhoto photo, {required Key key}) {
    final ready = photo.status == ProcessingStatus.done;
    final processed = photo.processedPath;
    // The styled side exists once the style is done (and is not "no style").
    final styledPath =
        ready &&
            processed != null &&
            processed != photo.originalPath &&
            photo.styleType != StyleType.none
        ? processed
        : null;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NeoIconButton(
                icon: _draftMode ? Icons.close : Icons.arrow_back,
                tooltip: _draftMode
                    ? AppLocalizations.of(context).printDiscard
                    : 'Back to camera',
                onPressed: _draftMode
                    ? () => _discardPrint(photo)
                    : () => setState(() => _showPrint = false),
                fill: NeoColors.yellow,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRINT NO. ${photo.id.substring(photo.id.length - 2)}',
                      style: TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'ORIGINAL + ${photo.styleType?.label ?? 'LEGACY EDIT'}'
                      '${photo.status == ProcessingStatus.done && photo.styleSource != null ? ' · ${photo.styleSource!.label}' : ''}',
                      style: TextStyle(
                        color: NeoColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(photo),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: NeoTheme.panel(
                    color: NeoColors.surface,
                    borderWidth: 2,
                    radius: _squareRadius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: BeforeAfterView(
                    key: ValueKey('before-after-${photo.id}'),
                    originalPath: photo.originalPath,
                    styledPath: styledPath,
                    styleLabel: photo.styleType?.label ?? 'EDIT',
                    showStyled: !_showOriginal,
                    onChanged: (styled) =>
                        setState(() => _showOriginal = !styled),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildStylePill(photo: photo),
          if (_processing && photo.status == ProcessingStatus.pending) ...[
            const SizedBox(height: 10),
            Text(
              'WORKING · ${_progressStage.toUpperCase()}',
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress,
              color: NeoColors.teal,
              backgroundColor: NeoColors.surface,
              minHeight: 6,
            ),
          ],
          const SizedBox(height: 16),
          if (photo.status == ProcessingStatus.failed &&
              photo.failureReason != null) ...[
            Text(
              photo.failureReason!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeoColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  formatPrintDate(photo.createdAt),
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Wraps onto a second line on narrow phones instead of overflowing.
              Flexible(
                flex: 3,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (photo.status == ProcessingStatus.failed)
                      NeoButton(
                        label: 'RETRY',
                        icon: Icons.refresh,
                        variant: NeoButtonVariant.primary,
                        onPressed: _processing ? null : _retryProcessing,
                      ),
                    if (_draftMode) ...[
                      NeoButton(
                        label: AppLocalizations.of(context).printDiscard,
                        icon: Icons.delete_outline,
                        variant: NeoButtonVariant.accent,
                        onPressed: () => _discardPrint(photo),
                      ),
                      NeoButton(
                        label: AppLocalizations.of(context).printPost,
                        icon: Icons.send_rounded,
                        variant: NeoButtonVariant.primary,
                        // While the style is applied there is nothing to send.
                        onPressed:
                            _processing ||
                                photo.status == ProcessingStatus.pending
                            ? null
                            : () => _postPrint(photo),
                      ),
                    ] else ...[
                      if (widget.onSendPrint != null &&
                          photo.status != ProcessingStatus.pending)
                        NeoButton(
                          label: AppLocalizations.of(context).sendPrintButton,
                          icon: Icons.send_rounded,
                          variant: NeoButtonVariant.primary,
                          onPressed: _processing
                              ? null
                              : () => widget.onSendPrint!(photo),
                        ),
                      NeoButton(
                        label: 'NEW SHOT',
                        icon: Icons.photo_camera_outlined,
                        variant: NeoButtonVariant.accent,
                        onPressed: () => setState(() => _showPrint = false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(NeoPhoto photo) => switch (photo.status) {
    ProcessingStatus.pending => const NeoLabel(
      'INKING',
      color: NeoColors.yellow,
      icon: Icons.hourglass_top,
    ),
    ProcessingStatus.done => const NeoLabel(
      'READY',
      color: NeoColors.teal,
      icon: Icons.check,
    ),
    ProcessingStatus.failed => const NeoLabel(
      'ORIGINAL SAFE',
      color: NeoColors.pink,
      icon: Icons.warning_amber_rounded,
    ),
  };
}
