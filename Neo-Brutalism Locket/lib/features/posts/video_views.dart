import 'dart:io';

import 'package:flutter/material.dart';
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

/// A short video post: loops silently while it is on screen. Shows the
/// thumbnail until the video is ready (or if it cannot be loaded).
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
    if (urls == null) return;
    final url = await urls.resolve('media', widget.path);
    if (url == null || !mounted) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      await controller.dispose();
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null)
          RemoteImage(path: thumb)
        else
          const ColoredBox(color: NeoColors.ink),
        const Center(child: VideoBadge(size: 44)),
      ],
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
  const VideoBadge({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: NeoColors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: NeoColors.ink, width: 2),
    ),
    child: Icon(
      Icons.play_arrow_rounded,
      size: size * 0.7,
      color: NeoColors.ink,
    ),
  );
}
