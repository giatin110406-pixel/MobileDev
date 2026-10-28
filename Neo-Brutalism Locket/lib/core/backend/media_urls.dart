import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

  bool _fresh(String key) {
    final cached = _cache[key];
    return cached != null &&
        cached.expires.isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  final _warmed = <String>{};

  /// Signs all of [paths] in ONE request and starts downloading them into the
  /// picture cache, a few at a time, so they are on the phone before anyone
  /// scrolls to them. Paths already warmed are skipped. Never throws.
  Future<void> warm(String bucket, Iterable<String> paths) async {
    final todo = <String>[
      for (final path in paths)
        if (_warmed.add('$bucket/$path')) path,
    ];
    if (todo.isEmpty) return;
    final need = [
      for (final path in todo)
        if (!_fresh('$bucket/$path')) path,
    ];
    if (need.isNotEmpty) {
      try {
        final signed = await Backend.client.storage
            .from(bucket)
            .createSignedUrlsResult(need, lifetime.inSeconds);
        final expires = DateTime.now().add(lifetime);
        for (final item in signed) {
          if (item is sb.SignedUrlSuccess) {
            _cache['$bucket/${item.path}'] = (
              url: item.signedUrl,
              expires: expires,
            );
          }
        }
      } catch (_) {
        // Not warmed after all: forget it so a later call can try again.
        for (final path in todo) {
          _warmed.remove('$bucket/$path');
        }
        return;
      }
    }
    // Download in the background, three at a time, in the order given.
    final queue = List.of(todo);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final path = queue.removeAt(0);
        final cached = _cache['$bucket/$path'];
        if (cached == null) continue;
        try {
          await DefaultCacheManager().getSingleFile(
            cached.url,
            key: '$bucket/$path',
          );
        } catch (_) {
          // The picture widget will fetch it itself when it is shown.
        }
      }
    }

    unawaited(Future.wait([worker(), worker(), worker()]));
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

/// Where a picture comes from: a file already on the phone, or a signed URL.
typedef _Found = ({File? file, String? url});

class _RemoteImageState extends State<RemoteImage> {
  Future<_Found>? _found;
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

  void _load({bool useCache = true}) {
    final source = _source;
    _found = source == null ? null : _find(source, useCache);
  }

  /// A picture that is already on the phone needs no signed URL: those are
  /// lost when the app closes and expire after an hour, so asking for one
  /// first made every picture wait for the network on each start. The cache
  /// is looked at first; [useCache] is off on a retry (a bad file in it).
  /// Only for the real storage, like [warmMedia]: other sources have no
  /// picture cache behind them.
  Future<_Found> _find(MediaUrls source, bool useCache) async {
    if (useCache && source is SupabaseMediaUrls) {
      try {
        final hit = await DefaultCacheManager().getFileFromCache(
          '${widget.bucket}/${widget.path}',
        );
        if (hit != null && await hit.file.exists()) {
          return (file: hit.file, url: null);
        }
      } catch (_) {
        // No cache to read (a test, a full disk): sign a URL instead.
      }
    }
    return (file: null, url: await source.resolve(widget.bucket, widget.path));
  }

  void _retry() => setState(() {
    _attempt++;
    _load(useCache: false);
  });

  Widget get _background {
    final preview = widget.previewPath;
    if (preview == null || preview == widget.path) {
      return const ColoredBox(color: Color(0xFFE5E5E5));
    }
    return RemoteImage(
      path: preview,
      bucket: widget.bucket,
      fit: widget.fit,
      placeholder: const ColoredBox(color: Color(0xFFE5E5E5)),
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
                color: Color(0xFF000000),
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
    tooltip: AppLocalizations.of(context).retryTooltip,
    onPressed: _retry,
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xFFF8EED2),
      foregroundColor: const Color(0xFF000000),
      side: const BorderSide(color: Color(0xFF000000), width: 2),
    ),
    icon: const Icon(Icons.refresh),
  );

  @override
  Widget build(BuildContext context) {
    // No way to reach storage here (no MediaUrlsScope): nothing will load.
    if (_found == null) return widget.placeholder ?? _background;
    return FutureBuilder<_Found>(
      future: _found,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loading();
        }
        final file = snapshot.data?.file;
        if (file != null) {
          return Image.file(
            file,
            key: ValueKey(_attempt),
            fit: widget.fit,
            errorBuilder: (context, _, error) => _failed(),
          );
        }
        final url = snapshot.data?.url;
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

/// Warms the pictures at [paths] in the `media` bucket when [urls] can (see
/// [SupabaseMediaUrls.warm]); does nothing for other sources.
void warmMedia(MediaUrls? urls, Iterable<String> paths) {
  if (urls is SupabaseMediaUrls) unawaited(urls.warm('media', paths));
}
