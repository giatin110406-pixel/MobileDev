import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/app/tab_swipe_detector.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_progress.dart';
import 'package:neo_brutalism_locket/core/print_sound.dart';
import 'package:neo_brutalism_locket/core/language.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/core/responsive.dart';
import 'package:neo_brutalism_locket/features/camera/before_after_view.dart';
import 'package:neo_brutalism_locket/features/camera/capture_options.dart';
import 'package:neo_brutalism_locket/features/camera/print_post_animation.dart';
import 'package:neo_brutalism_locket/features/camera/square_crop.dart';
import 'package:neo_brutalism_locket/features/camera/style_art.dart';
import 'package:neo_brutalism_locket/features/camera/style_pill.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/image_engine/fallback_text.dart';
import 'package:neo_brutalism_locket/features/albums/albums_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_composer.dart';
import 'package:neo_brutalism_locket/features/posts/post_overlay.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_working_label.dart';
import 'package:neo_brutalism_locket/features/photos/archive_screen.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_error_text.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/quest/quest_check_text.dart';
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
    required this.onOpenQuestSheet,
    required this.onQuestPassed,
    this.onSendPrint,
    this.onPostDraft,
    this.friends = const [],
    this.albums = const [],
    this.onPhotoRemoved,
    this.onVideoRecorded,
    this.header,
    this.embedPhoto,
    this.shutterKey,
    this.hideShutter = false,
  });

  final PlayerStore player;

  /// On the shutter, so the menu's SHOOT button can fly to it.
  final Key? shutterKey;

  /// The shutter is still on its way (flying up from the menu): keep its place
  /// empty until it lands.
  final bool hideShutter;

  /// The search vector of a shot kept on this phone (no account: the archive
  /// is searched on the phone). Null: shots get no vector here; posted shots
  /// get theirs in the outbox.
  final Future<String?> Function(Uint8List photo)? embedPhoto;

  /// Prints on this device, newest first (owned by the shell).
  final List<NeoPhoto> photos;
  final PhotoRepository repository;
  final StyleEngineFactory styleEngineFactory;
  final QuestVerifier questVerifier;

  /// A print was created or changed (saved already).
  final ValueChanged<NeoPhoto> onPhotoChanged;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenQuestSheet;

  /// Today's quest photo passed the check: style, caption and post it.
  final Future<void> Function(Quest quest, NeoPhoto photo, int day)
  onQuestPassed;

  /// Post this shot (to all friends or some). True when it was sent or
  /// queued; the shot is then removed from this phone. Null without an
  /// account: shots are kept on the phone instead.
  final Future<bool> Function(NeoPhoto photo)? onSendPrint;

  /// Post the shot just taken with what the person chose in the popup (caption,
  /// labels, who gets it). True when it was sent or queued. Null without an
  /// account: shots are kept on the phone and no popup opens.
  final Future<bool> Function(NeoPhoto photo, ComposerResult result)?
  onPostDraft;

  /// Who the post can go to (shown in the popup).
  final List<Friend> friends;

  /// Group albums open right now (shown in the popup as ticks).
  final List<Album> albums;

  /// A shot was thrown away or posted and is no longer on this phone.
  final ValueChanged<NeoPhoto>? onPhotoRemoved;

  /// A clip was recorded (hold the shutter). Null without an account: there
  /// is nowhere to keep videos on the phone, so recording is off.
  final Future<void> Function(File video)? onVideoRecorded;

  /// The top of the camera page: whose-posts picker and profile avatar.
  final Widget? header;

  @override
  State<CameraTab> createState() => CameraTabState();
}

class CameraTabState extends State<CameraTab> {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  NeoPhoto? _activePhoto;
  FlashMode _flashMode = FlashMode.off;
  StyleType _selectedStyleType = StyleType.none;

  /// The style swiped to on the pill; the photo keeps its own until APPLY.
  StyleType? _pendingStyle;
  String? _cameraMessage;
  int _cameraIndex = 0;
  bool _cameraLoading = true;
  bool _processing = false;
  bool _showPrint = false;

  /// What is being chosen for the shot just taken (caption, labels, who gets
  /// it); null on the live camera.
  ComposerController? _composer;
  bool _posting = false;

  bool get _draftMode =>
      widget.onPostDraft != null &&
      _draftId != null &&
      _activePhoto?.id == _draftId;

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
  bool _shutterDown = false;
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

  /// The camera's own file for the draft, shown (cover-cropped to the same
  /// square) while the cropped copy is still being saved.
  String? _shotPreviewPath;

  /// The white blink on the viewfinder the moment the shutter is pressed.
  bool _shutterFlash = false;

  /// Taking, checking or styling a photo right now.
  bool get busy => _processing;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _composer?.dispose();
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
      _notify(AppLocalizations.of(context).newDayQuest);
    }
  }

  /// Shows [photo] as the active print.
  void openPhoto(NeoPhoto photo) {
    setState(() {
      if (photo.id != _draftId) _draftId = null;
      _activePhoto = photo;
      _selectedStyleType = photo.styleType ?? StyleType.none;
      _pendingStyle = null;
      _showPrint = true;
    });
  }

  /// Back to the live camera. A draft stays on screen until it is posted
  /// or thrown away.
  void closePrint() {
    if (_showPrint) setState(() => _showPrint = false);
  }

  /// HỦY: the shot is deleted and the camera is back.
  void _discardPrint(NeoPhoto photo) => _removeShot(photo);

  /// POST: send the shot with what was chosen on the page.
  Future<void> _sendDraft() async {
    final photo = _activePhoto;
    final composer = _composer;
    if (photo == null || composer == null || _posting) return;
    if (!composer.hasRecipients) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _posting = true);
    try {
      await _postDraft(photo, composer.result());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _postDraft(NeoPhoto photo, ComposerResult result) async {
    final post = widget.onPostDraft;
    if (post == null) return;
    final posted = await post(photo, result);
    if (!posted || !mounted) return;
    // The post is sent; the stamp and print are only a show over it. Who gets
    // it picks the stamp: everyone is APPROVED, some friends is TOP SECRET.
    await playPrintPost(
      context,
      photo: photo,
      stamp: printStampFor(quest: false, private: result.recipients != null),
    );
    if (mounted) _removeShot(photo);
  }

  void _removeShot(NeoPhoto photo) {
    _discarded.add(photo.id);
    if (_draftId == photo.id) {
      _draftId = null;
      _shotPreviewPath = null;
      final composer = _composer;
      _composer = null;
      // After this frame: the page's text field is still listening until then.
      WidgetsBinding.instance.addPostFrameCallback((_) => composer?.dispose());
    }
    setState(() {
      _showPrint = false;
      if (_activePhoto?.id == photo.id) _activePhoto = null;
      _pendingStyle = null;
      _selectedStyleType = StyleType.none;
      _processing = false;
    });
    widget.onPhotoRemoved?.call(photo);
    widget.repository.delete(photo).catchError((Object _) {});
  }

  void _notify(String message) => showNeoSnack(context, message);

  /// What the quest check saw or why it failed. Debug builds only: the player
  /// is never told what was detected.
  String _debugSuffix() {
    if (!kDebugMode) return '';
    final verifier = widget.questVerifier;
    if (verifier is! QuestDiagnostics) return '';
    final seen = (verifier as QuestDiagnostics).lastDiagnosis;
    return seen == null ? '' : ' · DEBUG: $seen';
  }

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
      title: Text(
        AppLocalizations.of(context).outOfTriesTitle,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        AppLocalizations.of(context).outOfTriesBody,
        style: const TextStyle(color: NeoColors.ink),
      ),
      actions: [
        TextButton(
          onPressed: Haptics.tap(() => Navigator.pop(context)),
          child: Text(AppLocalizations.of(context).ok),
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
      _notify(AppLocalizations.of(context).newDayQuest);
      return;
    }
    setState(() {
      _processing = true;
      _checkingQuest = true;
    });
    try {
      final day = widget.player.today;
      final shot = await camera.takePicture();
      final bytes = await cropShotToSquare(shot.path);
      final QuestVerdict verdict;
      try {
        verdict = await widget.questVerifier.check(bytes, quest);
      } on QuestCheckUnavailable catch (error) {
        if (mounted) {
          _notify(
            '${questCheckText(AppLocalizations.of(context), error).toUpperCase()}${_debugSuffix()}',
          );
        }
        return;
      }
      if (verdict != QuestVerdict.match) {
        await widget.player.recordFailedAttempt();
        final left = widget.player.attemptsLeft;
        if (left == 0) {
          if (mounted) setState(() => _questModeQuest = null);
          await _showOutOfTries();
        } else if (mounted) {
          final l10n = AppLocalizations.of(context);
          _notify(
            verdict == QuestVerdict.screenRecapture
                ? l10n.screenTriesLeft(left, _debugSuffix())
                : l10n.wrongTriesLeft(left, _debugSuffix()),
          );
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
      if (mounted) {
        _notify(
          playerErrorText(AppLocalizations.of(context), error).toUpperCase(),
        );
      }
    } catch (_) {
      if (mounted) _notify(AppLocalizations.of(context).photoNotSaved);
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
        ResolutionPreset.veryHigh,
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
            ? AppLocalizations.of(context).cameraAccessOff
            : AppLocalizations.of(context).cameraUnavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraMessage = AppLocalizations.of(context).cameraUnavailable;
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
        } catch (e, st) {
          AppLog.warn('camera_experience', e, st);
        }
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

    setState(() {
      _processing = true;
      _shutterFlash = true;
    });
    Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _shutterFlash = false);
    });
    // With an account the draft page opens the moment the shutter is pressed,
    // "developing" until the shot comes back; the square copy is then cut and
    // saved behind it.
    final draft = widget.onPostDraft != null ? _openDraft() : null;
    try {
      final shot = await camera.takePicture();
      if (draft != null) {
        if (_discarded.contains(draft.id)) {
          // Thrown away while developing.
          File(shot.path).delete().ignore();
          return;
        }
        if (!mounted) return;
        setState(() {
          // The camera's file stands in until the square copy is saved (and
          // is what a throw-away deletes meanwhile).
          _activePhoto = NeoPhoto(
            id: draft.id,
            originalPath: shot.path,
            createdAt: draft.createdAt,
            status: draft.status,
            styleType: draft.styleType,
          );
          _shotPreviewPath = shot.path;
        });
      }
      // Save exactly what the square viewfinder showed: a centred 1:1 crop.
      final bytes = await cropShotToSquare(shot.path);
      await _startPrint(bytes, draft: draft);
    } catch (_) {
      if (!mounted) return;
      if (draft != null) {
        if (_discarded.contains(draft.id)) return;
        _removeShot(draft);
      } else {
        setState(() => _processing = false);
      }
      _notify(AppLocalizations.of(context).photoNotSaved);
    }
  }

  /// Opens the draft page at once, before the shot is even taken: its square
  /// "develops" until [_shoot] hands it the camera's file, and [_startPrint]
  /// fills in the saved photo under the same id.
  NeoPhoto _openDraft() {
    final now = DateTime.now();
    final draft = NeoPhoto(
      id: now.microsecondsSinceEpoch.toString(),
      originalPath: '',
      createdAt: now,
      status: ProcessingStatus.pending,
      styleType: _selectedStyleType,
    );
    _composer?.dispose();
    _composer = ComposerController(
      friends: widget.friends,
      albums: widget.albums,
    );
    setState(() {
      _activePhoto = draft;
      _draftId = draft.id;
      _shotPreviewPath = null;
      _pendingStyle = null;
      _showPrint = false;
    });
    return draft;
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
      _notify(AppLocalizations.of(context).photoOpenFailed);
    }
  }

  /// Saves square JPEG [bytes] as a new print with the selected style and
  /// starts processing it (shared by camera capture and gallery upload).
  /// [draft] is the page [_openDraft] already put up for this shot.
  Future<void> _startPrint(Uint8List bytes, {NeoPhoto? draft}) async {
    final photo = await widget.repository.saveOriginal(
      bytes,
      styleType: draft?.styleType ?? _selectedStyleType,
      id: draft?.id,
    );
    if (draft != null && _discarded.contains(draft.id)) {
      // Thrown away while it was being saved.
      await widget.repository.delete(photo);
      return;
    }
    if (!mounted) return;
    final draftMode = widget.onPostDraft != null;
    if (draftMode && draft == null) {
      _composer?.dispose();
      _composer = ComposerController(
        friends: widget.friends,
        albums: widget.albums,
      );
    }
    setState(() {
      _activePhoto = photo;
      _draftId = photo.id;
      if (draft == null) _shotPreviewPath = null;
      _pendingStyle = null;
      // With an account the shot stays on this page, in the viewfinder's place,
      // with its options below; without one the print page opens as before.
      _showPrint = !draftMode;
    });
    PrintSound.warmUp();
    widget.onPhotoChanged(photo);
    _processPhoto(photo);
    final embed = widget.embedPhoto;
    if (embed != null) unawaited(_saveVector(photo.id, bytes, embed));
  }

  Future<void> _saveVector(
    String photoId,
    Uint8List bytes,
    Future<String?> Function(Uint8List) embed,
  ) async {
    final vector = await embed(bytes);
    if (vector != null) await widget.repository.saveEmbedding(photoId, vector);
  }

  Future<void> _processPhoto(NeoPhoto photo) async {
    try {
      final styleType = photo.styleType ?? StyleType.none;
      final engine = widget.styleEngineFactory.create(styleType);
      if (mounted) {
        setState(() {
          _progress = 0;
        });
      }
      final output = await engine.process(
        File(photo.originalPath),
        styleType,
        onProgress: (stage, fraction) {
          if (!mounted) return;
          setState(() {
            _progress = fraction;
          });
        },
      );
      if (_discarded.contains(photo.id)) {
        try {
          await output.file.delete();
        } catch (e, st) {
          AppLog.warn('camera_experience', e, st);
        }
        return;
      }
      final complete = photo.copyWith(
        processedPath: output.file.path,
        styleSource: output.source,
        status: ProcessingStatus.done,
        clearFailureReason: true,
      );
      if (output.note != null && mounted) {
        _notify(
          AppLocalizations.of(context).fallbackUsed(
            fallbackNoteText(AppLocalizations.of(context), output.note!),
          ),
        );
      }
      await widget.repository.upsert(complete);
      widget.onPhotoChanged(complete);
      if (!mounted) return;
      setState(() {
        _activePhoto = complete;
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
        _processing = false;
      });
      _notify(AppLocalizations.of(context).styleFailedOriginalSafe);
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
      if (mounted) _notify(AppLocalizations.of(context).flashUnavailable);
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
      onVerticalDragEnd: _draftMode
          ? null
          : (details) {
              if ((details.primaryVelocity ?? 0) < -400) widget.onOpenFeed();
            },
      child: _draftMode ? _buildDraftBody() : _buildCameraBody(),
    );
  }

  Widget _buildCameraBody() {
    return _shootLayout(
      top: widget.header ?? const SizedBox.shrink(),
      strip: _questMode
          ? _buildQuestModeHeader(_questModeQuest!)
          : QuestStrip(store: widget.player, onTap: widget.onOpenQuestSheet),
      square: _buildViewfinder(),
      // The style is picked after the shot, on the draft; only a quest's
      // locked style is shown up front.
      belowSquare: [
        if (_questMode) ...[
          const SizedBox(height: 8),
          Center(
            child: StyleChip(
              style: _questModeQuest!.style,
              text: AppLocalizations.of(context).styleBadge(
                styleName(AppLocalizations.of(context), _questModeQuest!.style),
              ),
              icon: Icons.lock_outline,
            ),
          ),
        ],
      ],
      controls: _buildCaptureControls(),
      footer: Align(
        alignment: Alignment.topCenter,
        child: Semantics(
          button: true,
          label: AppLocalizations.of(context).openFeedLabel,
          child: InkWell(
            onTap: Haptics.tap(widget.onOpenFeed),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_up,
                    size: 18,
                    color: NeoColors.ink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).feedLabel,
                    style: const TextStyle(
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
    );
  }

  /// The shoot page's frame, shared by the live camera and the shot just
  /// taken: every slot keeps its size, so the square stays exactly where the
  /// viewfinder was and only what fills the slots changes.
  Widget _shootLayout({
    required Widget top,
    required Widget strip,
    required Widget square,
    List<Widget> belowSquare = const [],
    required Widget controls,
    required Widget footer,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, context.s(12), 18, context.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: context.s(46), child: top),
          // Room for the header's hard shadows before the quest card.
          SizedBox(height: context.s(22)),
          strip,
          SizedBox(height: context.s(20)),
          Expanded(child: _bigSquare(square)),
          ...belowSquare,
          SizedBox(height: context.s(16)),
          controls,
          const SizedBox(height: 6),
          // Tall enough for who gets the post on the draft.
          SizedBox(height: context.s(64), child: footer),
        ],
      ),
    );
  }

  /// How far the square may reach into the page's side padding.
  static const double _squareBleed = 10;

  /// A 1:1 square as big as the space allows, reaching [_squareBleed] into
  /// the side padding so it is wider than the controls around it.
  Widget _bigSquare(Widget child) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth + 2 * _squareBleed;
      final side = width < constraints.maxHeight
          ? width
          : constraints.maxHeight;
      // Loosen the minimums too: the Column hands down a tight box, which
      // would otherwise stretch the square to fill it.
      return OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: width,
        child: SizedBox.square(dimension: side, child: child),
      );
    },
  );

  /// The page right after a shot, laid out by [_shootLayout] like the live
  /// camera: the picture where the viewfinder was, the style pill where the
  /// quest card was, X / POST / options where the shutter was, and who gets
  /// it where the feed link was.
  Widget _buildDraftBody() {
    final l10n = AppLocalizations.of(context);
    final photo = _activePhoto!;
    final composer = _composer!;
    // The Scaffold above consumes the keyboard inset in this subtree's
    // MediaQuery, so the typing layout keys off the caption's focus instead.
    final ready = photo.status == ProcessingStatus.done && !_processing;
    final canSend = ready && composer.hasRecipients && !_posting;
    final hasOptions =
        composer.showTime ||
        composer.place != null ||
        composer.selectedAlbums.isNotEmpty;
    return ListenableBuilder(
      listenable: Listenable.merge([composer, composer.captionFocus]),
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        // While typing, the keyboard just covers the controls: the picture
        // keeps its full square (never squeezed) and sits at the top, with the
        // caption on it staying visible above the keyboard.
        child: composer.captionFocus.hasFocus
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  18 - _squareBleed,
                  12,
                  18 - _squareBleed,
                  0,
                ),
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _draftViewfinder(photo, composer),
                  ),
                ),
              )
            : _shootLayout(
                top: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Text(
                      l10n.composerTitle,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _statusBadge(photo),
                      ),
                    ),
                  ],
                ),
                // The quest card stays laid out (unseen) under the pill, so
                // the slot is exactly as tall as on the live camera.
                strip: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: QuestStrip(
                        store: widget.player,
                        onTap: widget.onOpenQuestSheet,
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child:
                            _processing &&
                                photo.status == ProcessingStatus.pending
                            ? NeoProgress(
                                value: _progress <= 0 ? null : _progress,
                                label: styleWorkingLabel(l10n, photo.styleType),
                              )
                            : _buildStylePill(photo: photo),
                      ),
                    ),
                  ],
                ),
                square: _draftViewfinder(photo, composer),
                controls: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: NeoIconButton(
                          icon: Icons.close,
                          tooltip: l10n.printDiscard,
                          fill: NeoColors.coral,
                          size: 54,
                          onPressed: _posting
                              ? null
                              : () => _discardPrint(photo),
                        ),
                      ),
                    ),
                    _sendButton(enabled: canSend, busy: _posting),
                    Expanded(
                      child: Center(
                        child: NeoIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: l10n.postOptionsTooltip,
                          // Lit while any option is on.
                          fill: hasOptions
                              ? NeoColors.accent
                              : NeoColors.surface,
                          size: 54,
                          onPressed: _posting
                              ? null
                              : () => _showPostOptions(composer),
                        ),
                      ),
                    ),
                  ],
                ),
                footer: _recipientsRow(composer),
              ),
      ),
    );
  }

  /// The options button's popup over the lower half of the screen: the time
  /// and place labels and the group albums, without leaving the page.
  Future<void> _showPostOptions(ComposerController composer) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return FractionallySizedBox(
          heightFactor: 0.5,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            decoration: NeoTheme.panel(radius: 16),
            child: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: composer,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.postOptionsTitle,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          _optionGroup(l10n.overlayTime, [
                            _optionPill(
                              label: l10n.optionsNone,
                              selected: !composer.showTime,
                              onTap: composer.showTime
                                  ? composer.toggleTime
                                  : null,
                            ),
                            _optionPill(
                              icon: Icons.schedule,
                              label: composer.time,
                              selected: composer.showTime,
                              onTap: composer.showTime
                                  ? null
                                  : composer.toggleTime,
                            ),
                          ]),
                          _optionGroup(l10n.overlayPlace, [
                            _optionPill(
                              label: l10n.optionsNone,
                              selected:
                                  composer.place == null &&
                                  !composer.findingPlace,
                              onTap: composer.place != null
                                  ? () => composer.togglePlace(_placeProblem)
                                  : null,
                            ),
                            _optionPill(
                              icon: Icons.place_outlined,
                              label: composer.findingPlace
                                  ? l10n.overlayFindingPlace
                                  : composer.place ?? l10n.optionsCurrentPlace,
                              selected:
                                  composer.place != null ||
                                  composer.findingPlace,
                              onTap:
                                  composer.place != null ||
                                      composer.findingPlace
                                  ? null
                                  : () => composer.togglePlace(_placeProblem),
                            ),
                          ]),
                          if (composer.albums.isNotEmpty)
                            _optionGroup(l10n.optionsAlbums, [
                              for (final album in composer.albums)
                                _optionPill(
                                  icon: Icons.photo_album_outlined,
                                  label: album.name,
                                  selected: composer.selectedAlbums.contains(
                                    album.id,
                                  ),
                                  onTap: () => composer.toggleAlbum(album.id),
                                ),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// One category of the options popup: its name over a wrap of pills.
  Widget _optionGroup(String title, List<Widget> pills) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: NeoColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: pills),
      ],
    ),
  );

  /// A pill in the options popup: sunken and yellow while chosen.
  Widget _optionPill({
    IconData? icon,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: NeoPress(
      onTap: onTap,
      offset: const Offset(2, 2),
      sunken: selected,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? NeoColors.accent : NeoColors.surface,
          border: Border.all(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(999),
          boxShadow: NeoPress.shadow(
            pressed || selected,
            offset: const Offset(2, 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: NeoColors.ink),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _placeProblem(PlaceProblem problem) {
    final l10n = AppLocalizations.of(context);
    _notify(switch (problem) {
      PlaceProblem.servicesOff => l10n.placeServicesOff,
      PlaceProblem.denied => l10n.placeDenied,
      PlaceProblem.failed => l10n.placeFailed,
    });
  }

  /// The shot, in the place of the viewfinder: hold to compare, labels on the
  /// corner and the caption typed right on the picture.
  Widget _draftViewfinder(NeoPhoto photo, ComposerController composer) {
    final l10n = AppLocalizations.of(context);
    final ready = photo.status == ProcessingStatus.done;
    final processed = photo.processedPath;
    final styledPath =
        ready &&
            processed != null &&
            processed != photo.originalPath &&
            photo.styleType != StyleType.none
        ? processed
        : null;
    return Container(
      decoration: NeoTheme.panel(
        color: NeoColors.surface,
        borderWidth: 2,
        radius: _squareRadius,
      ),
      foregroundDecoration: neoPanelOutline(radius: _squareRadius),
      child: NeoPanelClip(
        radius: _squareRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if ((_shotPreviewPath ?? photo.originalPath).isEmpty)
              _DevelopingShot(label: l10n.developingPhoto)
            else
              BeforeAfterView(
                key: ValueKey('draft-before-after-${photo.id}'),
                originalPath: _shotPreviewPath ?? photo.originalPath,
                styledPath: styledPath,
                styleLabel:
                    (photo.styleType == null
                        ? null
                        : styleName(l10n, photo.styleType!)) ??
                    l10n.editLabel,
              ),
            // The picture's own badges take the top corners; the labels sit above
            // the caption.
            Positioned(
              left: 16,
              bottom: 72,
              child: OverlayLabels(overlay: composer.overlay),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: NeoColors.ink.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: composer.caption,
                  focusNode: composer.captionFocus,
                  maxLength: maxCaptionLength,
                  maxLines: 2,
                  minLines: 1,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  cursorColor: NeoColors.surface,
                  style: const TextStyle(
                    color: NeoColors.surface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: l10n.composerCaptionHint,
                    hintStyle: TextStyle(
                      color: NeoColors.surface.withValues(alpha: 0.7),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The big round button where the shutter was: send the post.
  Widget _sendButton({required bool enabled, required bool busy}) => Semantics(
    button: true,
    enabled: enabled,
    label: AppLocalizations.of(context).composerPostAll,
    child: NeoPress(
      onTap: enabled ? _sendDraft : null,
      builder: (context, pressed) => Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: enabled ? NeoColors.accent : NeoColors.switchOff,
          shape: BoxShape.circle,
          border: Border.all(color: NeoColors.ink, width: 3),
          boxShadow: enabled ? NeoPress.shadow(pressed) : const [],
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: NeoColors.ink,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.send_rounded, size: 34, color: NeoColors.ink),
      ),
    ),
  );

  /// Where the feed link was: "All" and each friend, tap to pick who gets it.
  Widget _recipientsRow(ComposerController composer) {
    final l10n = AppLocalizations.of(context);
    // Small enough that a name fits under it in the footer slot.
    final avatarSize = context.s(40);
    if (widget.friends.isEmpty) {
      return Center(
        child: Text(
          l10n.composerNoFriends,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    Widget item({
      required Widget avatar,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: Haptics.tap(onTap),
        child: SizedBox(
          width: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(opacity: selected ? 1 : 0.4, child: avatar),
                  if (selected)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: NeoColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: NeoColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        item(
          avatar: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: NeoColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: const Icon(Icons.groups_rounded, color: NeoColors.ink),
          ),
          label: l10n.composerAllShort,
          selected: composer.all,
          onTap: composer.toggleAll,
        ),
        for (final friend in widget.friends)
          item(
            avatar: FriendAvatar(
              friend: friend.person.toPocketFriend(),
              size: avatarSize,
              shadow: false,
            ),
            label: friend.person.displayName.split(' ').first,
            selected: composer.selected.contains(friend.person.id),
            onTap: () => composer.toggle(friend.person.id),
          ),
      ],
    );
  }

  Widget _buildQuestModeHeader(Quest quest) {
    return Container(
      height: context.s(68),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: NeoTheme.panel(color: questStyleColor(quest.style)),
      child: Row(
        children: [
          Text(
            quest.emoji,
            style: const TextStyle(fontFamily: NeoFont.display, fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).questModeBanner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NeoColors.ink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).shootSubject(
                    quest.subjectFor(vietnamese: isVietnamese(context)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 18,
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
            tooltip: AppLocalizations.of(context).exitQuestMode,
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
    return TabSwipeExclusion(
      key: const ValueKey('viewfinder'),
      child: Container(
        decoration: NeoTheme.panel(
          color: NeoColors.surface,
          borderWidth: 2,
          radius: _squareRadius,
        ),
        foregroundDecoration: neoPanelOutline(radius: _squareRadius),
        child: NeoPanelClip(
          radius: _squareRadius,
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
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _shutterFlash ? 0.85 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
              // Only while something is going on: recording, or checking a quest
              // photo. The viewfinder is otherwise just the picture.
              if (_recording || _checkingQuest)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _recording
                        ? const NeoLabel(
                            'REC',
                            color: NeoColors.coral,
                            icon: Icons.circle,
                          )
                        : NeoLabel(
                            AppLocalizations.of(context).checkingPhoto,
                            color: NeoColors.accent,
                            icon: Icons.search,
                          ),
                  ),
                ),
              Positioned(top: 18, left: 18, child: _flashControl()),
              Positioned(top: 18, right: 18, child: _timerControl()),
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
                      color: NeoColors.accent,
                      radius: 999,
                    ),
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A small round control laid over the viewfinder: see-through while off so
  /// it hides little of the picture, solid once it is switched on.
  Widget _cornerControl({
    required IconData icon,
    required String tooltip,
    required bool active,
    required Color activeColor,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null ? null : Haptics.tap(onPressed),
        // A roomy touch area around a small disc.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? activeColor
                    : NeoColors.ink.withValues(alpha: 0.28),
                border: Border.all(
                  color: active
                      ? NeoColors.ink
                      : NeoColors.surface.withValues(alpha: 0.5),
                  width: active ? 2 : 1,
                ),
              ),
              child: Icon(
                icon,
                size: 17,
                color: active
                    ? NeoColors.ink
                    : NeoColors.surface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flashControl() => _cornerControl(
    icon: switch (_flashMode) {
      FlashMode.off => Icons.flash_off,
      FlashMode.auto => Icons.flash_auto,
      _ => Icons.flash_on,
    },
    tooltip: AppLocalizations.of(context).flashTooltip,
    active: _flashMode != FlashMode.off,
    activeColor: NeoColors.accent,
    onPressed: _toggleFlash,
  );

  Widget _timerControl() => _cornerControl(
    icon: switch (_shotTimer) {
      ShotTimer.off => Icons.timer_off_outlined,
      ShotTimer.three => Icons.timer_3,
      ShotTimer.ten => Icons.timer_10,
    },
    tooltip: _shotTimer == ShotTimer.off
        ? AppLocalizations.of(context).timerOff
        : AppLocalizations.of(context).timerSeconds(_shotTimer.seconds),
    active: _shotTimer != ShotTimer.off,
    activeColor: NeoColors.coral,
    onPressed: _countdown != null || _recording
        ? null
        : () => setState(() => _shotTimer = _shotTimer.next),
  );

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
              label: AppLocalizations.of(
                context,
              ).zoomSemantics(zoomLabel(level)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: Haptics.tap(() => _setZoom(level)),
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
                            ? NeoColors.accent
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

  /// The style control for a shot: one pill, swiped left/right between NO
  /// STYLE, 8-BIT and VAN GOGH, and the APPLY button beside it. Swiping only
  /// picks; the photo is re-styled when APPLY is pressed.
  Widget _buildStylePill({required NeoPhoto photo}) {
    final current = photo.styleType ?? _selectedStyleType;
    final picked = _pendingStyle ?? current;
    final canApply = !_processing && picked != current;
    return Center(
      child: Row(
        children: [
          Expanded(
            child: StylePill(
              value: picked,
              enabled: !_processing,
              onChanged: (styleType) =>
                  setState(() => _pendingStyle = styleType),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: canApply ? 1 : 0.4,
            child: NeoIconButton(
              icon: Icons.check_rounded,
              tooltip: AppLocalizations.of(context).styleApply,
              fill: NeoColors.accent,
              size: 44,
              onPressed: canApply
                  ? () {
                      setState(() => _pendingStyle = null);
                      _applyStyleToPhoto(photo, picked);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraFallback() {
    return ColoredBox(
      color: NeoColors.accent,
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
                    color: NeoColors.accent,
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
                      ? AppLocalizations.of(context).findingCamera
                      : _cameraMessage ??
                            AppLocalizations.of(context).cameraReady,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: NeoFont.display,
                    color: NeoColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).cameraAccessHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_cameraLoading) ...[
                  const SizedBox(height: 18),
                  NeoButton(
                    label: AppLocalizations.of(context).retry,
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
      children: [
        Expanded(
          // Quests must be shot live: no gallery in quest mode.
          child: _questMode
              ? const SizedBox.shrink()
              : Center(
                  child: NeoIconButton(
                    icon: Icons.add_photo_alternate_outlined,
                    tooltip: AppLocalizations.of(context).uploadPhotoTooltip,
                    onPressed: _processing ? null : _uploadFromGallery,
                    fill: NeoColors.coral,
                    size: 54,
                  ),
                ),
        ),
        KeyedSubtree(
          key: widget.shutterKey,
          child: Opacity(
            opacity: widget.hideShutter ? 0 : 1,
            child: _shutterButton(),
          ),
        ),
        Expanded(
          child: Center(
            child: NeoIconButton(
              icon: Icons.flip_camera_ios_outlined,
              tooltip: AppLocalizations.of(context).switchCameraTooltip,
              onPressed: _flipCamera,
              fill: NeoColors.accent,
              size: 54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shutterButton() => Semantics(
    button: true,
    label: AppLocalizations.of(context).takePhotoLabel,
    hint: widget.onVideoRecorded == null
        ? null
        : AppLocalizations.of(context).holdForVideo,
    child: Listener(
      onPointerDown: (_) => setState(() => _shutterDown = true),
      onPointerUp: (_) => setState(() => _shutterDown = false),
      onPointerCancel: (_) => setState(() => _shutterDown = false),
      child: GestureDetector(
        onTap: _processing
            ? null
            : () {
                Haptics.press();
                _capture();
              },
        onLongPressStart: _canRecord
            ? (_) {
                Haptics.heavy();
                _startVideo();
              }
            : null,
        onLongPressEnd: _canRecord || _recording
            ? (_) {
                Haptics.light();
                _stopVideo();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(7),
          transform: Matrix4.translationValues(
            _shutterDown && !_processing ? 4 : 0,
            _shutterDown && !_processing ? 4 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: _processing ? NeoColors.switchOff : NeoColors.ink,
            shape: BoxShape.circle,
            border: Border.all(color: NeoColors.ink, width: 2),
            boxShadow: _processing || _shutterDown
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
              color: _recording ? NeoColors.coral : NeoColors.accent,
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
  );

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
                icon: Icons.arrow_back,
                tooltip: AppLocalizations.of(context).backToCameraTooltip,
                onPressed: () => setState(() => _showPrint = false),
                fill: NeoColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      ).printNumber(photo.id.substring(photo.id.length - 2)),
                      style: TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      AppLocalizations.of(context).originalPlusStyle(
                            (photo.styleType == null
                                    ? null
                                    : styleName(
                                        AppLocalizations.of(context),
                                        photo.styleType!,
                                      )) ??
                                AppLocalizations.of(context).legacyEdit,
                          ) +
                          (photo.status == ProcessingStatus.done &&
                                  photo.styleSource != null
                              ? ' · ${styleSourceLabel(AppLocalizations.of(context), photo.styleSource!)}'
                              : ''),
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
                  foregroundDecoration: neoPanelOutline(radius: _squareRadius),
                  child: NeoPanelClip(
                    radius: _squareRadius,
                    child: BeforeAfterView(
                      key: ValueKey('before-after-${photo.id}'),
                      originalPath: photo.originalPath,
                      styledPath: styledPath,
                      styleLabel:
                          (photo.styleType == null
                              ? null
                              : styleName(
                                  AppLocalizations.of(context),
                                  photo.styleType!,
                                )) ??
                          AppLocalizations.of(context).editLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildStylePill(photo: photo),
          if (_processing && photo.status == ProcessingStatus.pending) ...[
            const SizedBox(height: 12),
            NeoProgress(
              value: _progress <= 0 ? null : _progress,
              label: styleWorkingLabel(
                AppLocalizations.of(context),
                photo.styleType,
              ),
            ),
          ],
          const SizedBox(height: 12),
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
                  formatPrintDate(
                    AppLocalizations.of(context),
                    photo.createdAt,
                  ),
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
                        label: AppLocalizations.of(context).retryShort,
                        icon: Icons.refresh,
                        variant: NeoButtonVariant.primary,
                        onPressed: _processing ? null : _retryProcessing,
                      ),
                    ...[
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
                        label: AppLocalizations.of(context).newShot,
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
    ProcessingStatus.pending => NeoLabel(
      AppLocalizations.of(context).statusInking,
      color: NeoColors.accent,
      icon: Icons.hourglass_top,
    ),
    ProcessingStatus.done => NeoLabel(
      AppLocalizations.of(context).statusReady,
      color: NeoColors.accent,
      icon: Icons.check,
    ),
    ProcessingStatus.failed => NeoLabel(
      AppLocalizations.of(context).statusOriginalSafe,
      color: NeoColors.coral,
      icon: Icons.warning_amber_rounded,
    ),
  };
}

/// The draft's square while the shot is still being taken: a print slowly
/// coming up out of the dark, like an instant photo developing.
class _DevelopingShot extends StatefulWidget {
  const _DevelopingShot({required this.label});

  final String label;

  @override
  State<_DevelopingShot> createState() => _DevelopingShotState();
}

class _DevelopingShotState extends State<_DevelopingShot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) => ColoredBox(
      color: Color.lerp(
        NeoColors.ink,
        NeoColors.ink.withValues(alpha: 0.55),
        Curves.easeInOut.transform(_pulse.value),
      )!,
      child: child,
    ),
    child: Center(
      child: NeoLabel(
        widget.label,
        color: NeoColors.accent,
        icon: Icons.hourglass_top,
      ),
    ),
  );
}
