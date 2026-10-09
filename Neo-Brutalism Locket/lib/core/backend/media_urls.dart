import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';

/// Turns a path in a private storage bucket into a URL the phone can load.
abstract interface class MediaUrls {
  /// Null when the file cannot be reached (offline, deleted, no access).
  Future<String?> resolve(String bucket, String path);
}

/// Signed URLs from Supabase Storage, reused until shortly before they expire.
class SupabaseMediaUrls implements MediaUrls {
  SupabaseMediaUrls({this.lifetime = const Duration(hours: 1)});

  final Duration lifetime;
  final _cache = <String, ({String url, DateTime expires})>{};
  final _pending = <String, Future<String?>>{};

  @override
  Future<String?> resolve(String bucket, String path) {
    final key = '$bucket/$path';
    final cached = _cache[key];
    if (cached != null &&
        cached.expires.isAfter(
          DateTime.now().add(const Duration(minutes: 5)),
        )) {
      return Future.value(cached.url);
    }
    return _pending[key] ??= _sign(
      bucket,
      path,
      key,
    ).whenComplete(() => _pending.remove(key));
  }

  Future<String?> _sign(String bucket, String path, String key) async {
    try {
      final url = await Backend.client.storage
          .from(bucket)
          .createSignedUrl(path, lifetime.inSeconds);
      _cache[key] = (url: url, expires: DateTime.now().add(lifetime));
      return url;
    } catch (_) {
      return null;
    }
  }
}

/// Gives widgets below it a [MediaUrls] (the app root provides the real one).
class MediaUrlsScope extends InheritedWidget {
  const MediaUrlsScope({super.key, required this.urls, required super.child});

  final MediaUrls urls;

  static MediaUrls? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaUrlsScope>()?.urls;

  @override
  bool updateShouldNotify(MediaUrlsScope oldWidget) => urls != oldWidget.urls;
}

/// A picture from a private bucket. Cached on disk by its path, so a new
/// signed URL does not download it again. While it loads, [previewPath] (a
/// small copy, usually already cached) or a spinner shows; when it cannot be
/// loaded, a tap tries again.
class RemoteImage extends StatefulWidget {
  const RemoteImage({
    super.key,
    required this.path,
    this.bucket = 'media',
    this.fit = BoxFit.cover,
    this.placeholder,
    this.previewPath,
  });

  final String path;
  final String bucket;
  final BoxFit fit;

  /// Shown while loading and when the picture cannot be loaded (instead of
  /// the spinner and the retry button).
  final Widget? placeholder;

  /// A smaller picture in the same bucket to show until [path] arrives.
  final String? previewPath;

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  Future<String?>? _url;
  MediaUrls? _source;
  int _attempt = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = MediaUrlsScope.maybeOf(context);
    if (source != _source) {
      _source = source;
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.bucket != widget.bucket) {
      _load();
    }
  }

  void _load() => _url = _source?.resolve(widget.bucket, widget.path);

  void _retry() => setState(() {
    _attempt++;
    _load();
  });

  Widget get _background {
    final preview = widget.previewPath;
    if (preview == null || preview == widget.path) {
      return const ColoredBox(color: Color(0xFFE8E0D4));
    }
    return RemoteImage(
      path: preview,
      bucket: widget.bucket,
      fit: widget.fit,
      placeholder: const ColoredBox(color: Color(0xFFE8E0D4)),
    );
  }

  Widget _loading() =>
      widget.placeholder ??
      Stack(
        fit: StackFit.expand,
        children: [
          _background,
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      );

  /// A retry button on big pictures; small ones (grid tiles, avatars) keep
  /// their own tap and try again when shown next time.
  Widget _failed() =>
      widget.placeholder ??
      LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            _background,
            if (constraints.biggest.shortestSide >= 160)
              Center(child: _retryButton())
            else
              const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 20),
              ),
          ],
        ),
      );

  Widget _retryButton() => IconButton.filled(
    tooltip: 'Retry',
    onPressed: _retry,
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xFFFDF2E9),
      foregroundColor: const Color(0xFF1A1A1A),
      side: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
    ),
    icon: const Icon(Icons.refresh),
  );

  @override
  Widget build(BuildContext context) {
    // No way to reach storage here (no MediaUrlsScope): nothing will load.
    if (_url == null) return widget.placeholder ?? _background;
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loading();
        }
        final url = snapshot.data;
        if (url == null) return _failed();
        return CachedNetworkImage(
          key: ValueKey(_attempt),
          imageUrl: url,
          cacheKey: '${widget.bucket}/${widget.path}',
          fit: widget.fit,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (context, _) => _loading(),
          errorWidget: (context, _, error) => _failed(),
        );
      },
    );
  }
}
