import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:video_player/video_player.dart';

/// Plays [controller] filling its box (centre-cropped like the photos).
class _CoverVideo extends StatelessWidget {
  const _CoverVideo(this.controller);

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width == 0 ? 1 : size.width,
          height: size.height == 0 ? 1 : size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

/// Makes [controller] loop for good: `setLooping` is not honoured on every
/// phone, so when the clip ends without looping it is sent back to the start.
void _keepLooping(VideoPlayerController controller) {
  controller.addListener(() {
    final value = controller.value;
    if (!value.isInitialized || value.isPlaying || value.isBuffering) return;
    final end = value.duration;
    if (end > Duration.zero && value.position >= end) {
      controller
        ..seekTo(Duration.zero)
        ..play();
    }
  });
}

/// A short video post: starts by itself, silently, and loops while it is on
/// screen, with no play button to press. Until it is ready the thumbnail shows
/// with a spinner; if it cannot be loaded a tap tries again.
class RemoteVideo extends StatefulWidget {
  const RemoteVideo({super.key, required this.path, this.thumbPath});

  final String path;
  final String? thumbPath;

  @override
  State<RemoteVideo> createState() => _RemoteVideoState();
}

class _RemoteVideoState extends State<RemoteVideo> {
  VideoPlayerController? _controller;
  bool _started = false;
  bool _failed = false;

  /// No way to reach storage here: nothing will ever load, so no spinner.
  bool _noSource = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final urls = MediaUrlsScope.maybeOf(context);
    if (urls == null) {
      _noSource = true;
      return;
    }
    if (_failed) setState(() => _failed = false);
    final key = 'media/${widget.path}';
    VideoPlayerController? controller;
    try {
      // A copy already on the phone (warmed while the feed loaded) starts at
      // once and loops without buffering.
      final cached = await DefaultCacheManager().getFileFromCache(key);
      if (cached != null) {
        controller = VideoPlayerController.file(cached.file);
      } else {
        final url = await urls.resolve('media', widget.path);
        if (url == null || !mounted) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        // Keep a copy for next time (and for the loop).
        unawaited(
          DefaultCacheManager()
              .getSingleFile(url, key: key)
              .then<void>((_) {}, onError: (_) {}),
        );
      }
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      _keepLooping(controller);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (error, stack) {
      AppLog.warn('video', error, stack);
      await controller?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return _CoverVideo(controller);
    }
    final thumb = widget.thumbPath;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _failed ? _load : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumb != null)
            RemoteImage(path: thumb)
          else
            const ColoredBox(color: NeoColors.ink),
          Center(
            child: _noSource
                ? const VideoBadge(size: 44)
                : _failed
                ? const VideoBadge(size: 44, icon: Icons.refresh_rounded)
                : const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: NeoColors.surface,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The recorded clip, looping, before it is sent.
class LocalVideoPreview extends StatefulWidget {
  const LocalVideoPreview({super.key, required this.path});

  final String path;

  @override
  State<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<LocalVideoPreview> {
  late final VideoPlayerController _controller = VideoPlayerController.file(
    File(widget.path),
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      _keepLooping(_controller);
      await _controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Leave the placeholder up.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready
      ? _CoverVideo(_controller)
      : const ColoredBox(
          color: NeoColors.ink,
          child: Center(child: VideoBadge(size: 44)),
        );
}

/// ▶ in a circle: marks a video.
class VideoBadge extends StatelessWidget {
  const VideoBadge({
    super.key,
    this.size = 22,
    this.icon = Icons.play_arrow_rounded,
  });

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: NeoColors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: NeoColors.ink, width: 2),
    ),
    child: Icon(icon, size: size * 0.7, color: NeoColors.ink),
  );
}
