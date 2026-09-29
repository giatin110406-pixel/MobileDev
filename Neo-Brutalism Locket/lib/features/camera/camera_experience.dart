import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/image_engine/image_processing_backend.dart';
import 'package:neo_brutalism_locket/features/image_engine/android_selfie_segmentation.dart';
import 'package:neo_brutalism_locket/features/image_engine/background_preset.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';

class CameraExperienceScreen extends StatefulWidget {
  const CameraExperienceScreen({super.key});

  @override
  State<CameraExperienceScreen> createState() => _CameraExperienceScreenState();
}

class _CameraExperienceScreenState extends State<CameraExperienceScreen> {
  final PhotoRepository _repository = PhotoRepository();
  final SocialRepository _socialRepository = SocialRepository();
  final AndroidSelfieSegmentation _segmentation = AndroidSelfieSegmentation();
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  List<NeoPhoto> _photos = [];
  List<PocketFriend> _friends = [];
  List<PocketMessage> _messages = [];
  NeoPhoto? _activePhoto;
  PocketFriend? _activeFriend;
  FlashMode _flashMode = FlashMode.off;
  ImageBackgroundPreset _backgroundPreset = imageBackgroundPresets.first;
  String? _cameraMessage;
  int _cameraIndex = 0;
  int _tabIndex = 0;
  bool _cameraLoading = true;
  bool _processing = false;
  bool _showOriginal = false;
  bool _showPrint = false;

  @override
  void initState() {
    super.initState();
    _loadArchive();
    _loadSocial();
    _initializeCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _loadArchive() async {
    try {
      final photos = await _repository.loadPhotos();
      if (mounted) setState(() => _photos = photos);
    } catch (_) {
      _notify('ARCHIVE COULD NOT BE READ');
    }
  }

  Future<void> _loadSocial() async {
    try {
      final snapshot = await _socialRepository.load();
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
      });
    } catch (_) {
      _notify('FRIENDS COULD NOT BE LOADED');
    }
  }

  Future<void> _addFriend() async {
    final draft = await showAddFriendSheet(context);
    if (draft == null) return;
    try {
      final snapshot = await _socialRepository.addFriend(
        name: draft.name,
        handle: draft.handle,
      );
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
      });
      _notify('${draft.name.toUpperCase()} ADDED LOCALLY');
    } on FormatException catch (error) {
      _notify(error.message.toUpperCase());
    }
  }

  Future<void> _openFriend(PocketFriend friend) async {
    final snapshot = await _socialRepository.markThreadRead(friend.id);
    if (!mounted) return;
    setState(() {
      _activeFriend = friend;
      _friends = snapshot.friends;
      _messages = snapshot.messages;
      _tabIndex = 2;
    });
  }

  Future<void> _sendSocialMessage(String text, String? photoPath) async {
    final friend = _activeFriend;
    if (friend == null) return;
    try {
      final snapshot = await _socialRepository.sendMessage(
        friendId: friend.id,
        text: text,
        photoPath: photoPath,
      );
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
      });
    } on FormatException catch (error) {
      _notify(error.message.toUpperCase());
    }
  }

  Future<void> _sendLatestPrint() async {
    final friend = _activeFriend;
    if (friend == null) return;
    if (_photos.isEmpty) {
      _notify('TAKE A PRINT BEFORE SHARING');
      return;
    }
    final photo = _photos.first;
    await _sendSocialMessage('', photo.processedPath ?? photo.originalPath);
  }

  Future<void> _removeActiveFriend() async {
    final friend = _activeFriend;
    if (friend == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        title: const Text(
          'REMOVE FRIEND?',
          style: TextStyle(color: NeoColors.ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Remove ${friend.name} and this local thread from this device?',
          style: const TextStyle(color: NeoColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    final snapshot = await _socialRepository.removeFriend(friend.id);
    if (!mounted) return;
    setState(() {
      _friends = snapshot.friends;
      _messages = snapshot.messages;
      _activeFriend = null;
      _tabIndex = 1;
    });
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
      if (!mounted) return;
      setState(() {
        _cameraIndex = nextIndex;
        _cameraLoading = false;
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

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _processing) return;

    setState(() => _processing = true);
    try {
      final shot = await camera.takePicture();
      final bytes = await shot.readAsBytes();
      final photo = await _repository.saveOriginal(bytes);
      if (!mounted) return;
      setState(() {
        _activePhoto = photo;
        _showOriginal = true;
        _showPrint = true;
        _tabIndex = 0;
        _processing = false;
      });
      _processPhoto(photo, bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _notify('PHOTO DID NOT SAVE. TRY AGAIN.');
    }
  }

  Future<void> _processPhoto(NeoPhoto photo, Uint8List bytes) async {
    try {
      final segmentationInput = await compute(
        prepareSegmentationImageInBackground,
        bytes,
      );
      final personMask = await _segmentation.segment(segmentationInput);
      final processedBytes = await compute(processPhotoWithMaskInBackground, {
        'imageBytes': segmentationInput,
        'maskWidth': personMask?.width,
        'maskHeight': personMask?.height,
        'maskConfidences': personMask?.confidences,
        'backgroundRgb': _backgroundPreset.rgb,
      });
      final path = await _repository.saveProcessed(photo.id, processedBytes);
      final complete = photo.copyWith(
        processedPath: path,
        status: ProcessingStatus.done,
      );
      await _repository.upsert(complete);
      if (!mounted) return;
      setState(() {
        _activePhoto = complete;
        _photos = [complete, ..._photos.where((item) => item.id != photo.id)];
        _showOriginal = false;
      });
    } catch (_) {
      final failed = photo.copyWith(status: ProcessingStatus.failed);
      await _repository.upsert(failed);
      if (!mounted) return;
      setState(() {
        _activePhoto = failed;
        _photos = [failed, ..._photos.where((item) => item.id != photo.id)];
      });
      _notify('STYLE PASS FAILED. ORIGINAL IS SAFE.');
    }
  }

  Future<void> _retryProcessing() async {
    final photo = _activePhoto;
    if (photo == null || _processing) return;
    setState(() => _processing = true);
    try {
      final bytes = await File(photo.originalPath).readAsBytes();
      final pending = photo.copyWith(status: ProcessingStatus.pending);
      await _repository.upsert(pending);
      if (!mounted) return;
      setState(() {
        _activePhoto = pending;
        _processing = false;
      });
      _processPhoto(pending, bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _notify('ORIGINAL FILE COULD NOT BE READ');
    }
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

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      _activeFriend = null;
      if (index == 0) _showPrint = false;
    });
    if (index == 1 || index == 2) _loadSocial();
    if (index == 3) _loadArchive();
  }

  void _openPhoto(NeoPhoto photo) {
    setState(() {
      _activePhoto = photo;
      _showPrint = true;
      _showOriginal = photo.status != ProcessingStatus.done;
      _tabIndex = 0;
    });
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: NeoColors.surface,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: NeoColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final showPrint = _tabIndex == 0 && _showPrint && _activePhoto != null;
    final page = switch (_tabIndex) {
      0 =>
        showPrint
            ? _buildPrint(_activePhoto!, key: const ValueKey('print'))
            : _buildCamera(key: const ValueKey('camera')),
      1 => FriendsScreen(
        key: const ValueKey('friends'),
        friends: _friends,
        messages: _messages,
        onAddFriend: _addFriend,
        onOpenFriend: _openFriend,
      ),
      2 =>
        _activeFriend == null
            ? InboxScreen(
                key: const ValueKey('inbox'),
                friends: _friends,
                messages: _messages,
                onOpenFriend: _openFriend,
              )
            : ConversationScreen(
                key: ValueKey('thread-${_activeFriend!.id}'),
                friend: _activeFriend!,
                messages: _messages
                    .where((message) => message.friendId == _activeFriend!.id)
                    .toList(),
                onBack: () => setState(() => _activeFriend = null),
                onSend: _sendSocialMessage,
                onSendLatestPhoto: _sendLatestPrint,
                onRemoveFriend: _removeActiveFriend,
              ),
      _ => _buildArchive(key: const ValueKey('archive')),
    };
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: page,
        ),
      ),
      bottomNavigationBar: _buildTabs(),
    );
  }

  Widget _buildCamera({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(showFlash: true),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAMERA / 01',
                      style: TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Make a print.',
                      style: TextStyle(
                        color: NeoColors.ink,
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const NeoLabel(
                'ON DEVICE',
                color: NeoColors.yellow,
                icon: Icons.lock_outline,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (Platform.isAndroid)
            _buildBackgroundPicker()
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: NeoLabel(
                'BG CUTOUT / ANDROID ONLY',
                color: NeoColors.surface,
              ),
            ),
          const SizedBox(height: 12),
          Expanded(child: _buildViewfinder()),
          const SizedBox(height: 20),
          _buildCaptureControls(),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'ORIGINAL STAYS ON THIS DEVICE',
              style: TextStyle(
                color: NeoColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({bool showFlash = false}) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: NeoTheme.panel(
            color: NeoColors.pink,
            borderWidth: 2,
            radius: 8,
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            color: NeoColors.ink,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POCKET PORTRAIT',
                style: TextStyle(
                  color: NeoColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'NEO BRUTAL CAMERA CLUB',
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showFlash)
          NeoIconButton(
            icon: _flashMode == FlashMode.off
                ? Icons.flash_off
                : Icons.flash_on,
            tooltip: 'Change flash mode',
            fill: NeoColors.yellow,
            onPressed: _toggleFlash,
          ),
      ],
    );
  }

  Widget _buildViewfinder() {
    final camera = _camera;
    return Container(
      decoration: NeoTheme.panel(color: NeoColors.surface, borderWidth: 2),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            CameraPreview(camera)
          else
            _buildCameraFallback(),
          Positioned(
            top: 12,
            left: 12,
            child: NeoLabel(
              _cameraLoading
                  ? 'STARTING'
                  : _cameraMessage == null
                  ? 'LIVE'
                  : 'NO CAMERA',
              color: _cameraMessage == null ? NeoColors.teal : NeoColors.yellow,
              icon: _cameraMessage == null
                  ? Icons.circle
                  : Icons.warning_amber_rounded,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: NeoLabel(
              '$_archiveCount PRINTS',
              color: NeoColors.pink,
              icon: Icons.photo_library_outlined,
            ),
          ),
          Positioned(
            right: 10,
            top: 52,
            child: ExcludeSemantics(
              child: Image.asset(
                'figma_inspiration/Star 6.png',
                width: 42,
                height: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPicker() {
    return Row(
      children: [
        const Text(
          'BG',
          style: TextStyle(
            color: NeoColors.ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        for (final preset in imageBackgroundPresets) ...[
          Tooltip(
            message: '${preset.label} background',
            child: Semantics(
              button: true,
              selected: preset.rgbHex == _backgroundPreset.rgbHex,
              label: '${preset.label} background',
              child: GestureDetector(
                onTap: () => setState(() => _backgroundPreset = preset),
                child: Container(
                  width: 27,
                  height: 27,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Color(preset.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeoColors.ink,
                      width: preset.rgbHex == _backgroundPreset.rgbHex ? 3 : 1.5,
                    ),
                    boxShadow: preset.rgbHex == _backgroundPreset.rgbHex
                        ? const [
                            BoxShadow(
                              color: NeoColors.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        NeoLabel(_backgroundPreset.label, color: Color(_backgroundPreset.colorValue)),
      ],
    );
  }

  Widget _buildCameraFallback() {
    return ColoredBox(
      color: NeoColors.blue,
      child: Center(
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
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _recentThumb(),
        Semantics(
          button: true,
          label: 'Take photo',
          child: GestureDetector(
            onTap: _processing ? null : _capture,
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
                  color: NeoColors.yellow,
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
                    : null,
              ),
            ),
          ),
        ),
        NeoIconButton(
          icon: Icons.flip_camera_ios_outlined,
          tooltip: 'Switch camera',
          onPressed: _flipCamera,
          fill: NeoColors.purple,
        ),
      ],
    );
  }

  Widget _recentThumb() {
    final photo = _photos.isEmpty ? null : _photos.first;
    return Semantics(
      button: true,
      label: 'Open archive',
      child: GestureDetector(
        onTap: () => _selectTab(3),
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
    final imagePath = _showOriginal || !ready
        ? photo.originalPath
        : photo.processedPath;
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
                tooltip: 'Back to camera',
                onPressed: () => setState(() => _showPrint = false),
                fill: NeoColors.yellow,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRINT NO. 01',
                      style: TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'ORIGINAL + NEO EDIT',
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
            child: Container(
              decoration: NeoTheme.panel(
                color: NeoColors.surface,
                borderWidth: 2,
              ),
              clipBehavior: Clip.antiAlias,
              child: imagePath == null
                  ? const Center(
                      child: CircularProgressIndicator(color: NeoColors.teal),
                    )
                  : Image.file(
                      File(imagePath),
                      key: ValueKey(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Text(
                              'IMAGE NOT FOUND',
                              style: TextStyle(
                                color: NeoColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: NeoTheme.panel(
              color: NeoColors.surface,
              borderWidth: 2,
            ),
            child: NeoSwitch(
              value: !_showOriginal,
              onChanged: ready
                  ? (showNeo) => setState(() => _showOriginal = !showNeo)
                  : null,
              label: _showOriginal ? 'ORIGINAL' : 'NEO PRINT',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(photo.createdAt),
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (photo.status == ProcessingStatus.failed)
                NeoButton(
                  label: 'RETRY',
                  icon: Icons.refresh,
                  variant: NeoButtonVariant.primary,
                  onPressed: _processing ? null : _retryProcessing,
                ),
              const SizedBox(width: 10),
              NeoButton(
                label: 'NEW SHOT',
                icon: Icons.photo_camera_outlined,
                variant: NeoButtonVariant.accent,
                onPressed: () => setState(() => _showPrint = false),
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

  Widget _buildArchive({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCAL COLLECTION',
                      style: TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Print archive',
                      style: TextStyle(
                        color: NeoColors.ink,
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              NeoLabel('${_photos.length} ITEMS', color: NeoColors.purple),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _photos.isEmpty
                ? _buildEmptyArchive()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    itemCount: _photos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildArchiveRow(_photos[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveRow(NeoPhoto photo, int index) {
    final thumbnail = photo.processedPath ?? photo.originalPath;
    return InkWell(
      onTap: () => _openPhoto(photo),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: NeoTheme.panel(
          color: index.isEven ? NeoColors.surface : NeoColors.yellow,
          borderWidth: 2,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: NeoColors.teal,
                border: Border.all(color: NeoColors.ink, width: 2),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: NeoColors.ink,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(thumbnail),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.photo_outlined, color: NeoColors.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRINT ${(_photos.length - index).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatDate(photo.createdAt)}  /  ${_statusText(photo.status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.photo_camera_outlined, color: NeoColors.ink, size: 23),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyArchive() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: NeoTheme.panel(color: NeoColors.blue, borderWidth: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: NeoTheme.panel(
              color: NeoColors.pink,
              borderWidth: 2,
              radius: 999,
            ),
            child: const Icon(
              Icons.collections_outlined,
              color: NeoColors.ink,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NOTHING\nPRINTED YET',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeoColors.ink,
              fontSize: 24,
              height: 0.98,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'YOUR PHOTOS STAY IN THIS DEVICE-ONLY ARCHIVE.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeoColors.ink,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          NeoButton(
            label: 'OPEN CAMERA',
            icon: Icons.photo_camera_outlined,
            variant: NeoButtonVariant.primary,
            onPressed: () => _selectTab(0),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 22, 12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              _tab(index: 0, icon: Icons.photo_camera_outlined, label: 'SHOOT'),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(index: 1, icon: Icons.people_alt_outlined, label: 'FRIENDS'),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(index: 2, icon: Icons.chat_bubble_outline, label: 'INBOX'),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(index: 3, icon: Icons.grid_view_rounded, label: 'PRINTS'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _tabIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => _selectTab(index),
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: double.infinity,
            decoration: BoxDecoration(
              color: selected ? NeoColors.teal : NeoColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: NeoColors.ink, size: 18),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(ProcessingStatus status) => switch (status) {
    ProcessingStatus.pending => 'INKING',
    ProcessingStatus.done => 'NEO PRINT READY',
    ProcessingStatus.failed => 'ORIGINAL SAVED',
  };

  int get _archiveCount {
    final activePhoto = _activePhoto;
    if (activePhoto == null ||
        _photos.any((photo) => photo.id == activePhoto.id)) {
      return _photos.length;
    }
    return _photos.length + 1;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}  $hour:$minute $period';
  }
}
