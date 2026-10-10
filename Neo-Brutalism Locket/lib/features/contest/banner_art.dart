import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

/// Where painting-banners get their picture from, and a memory of what was
/// already fetched (a profile may show the same banner many times). Make one for
/// the whole app (AppShell does) and hand it down with [ContestArtScope].
class ContestArtCache {
  ContestArtCache(this.repository);

  final ContestRepository repository;
  final Map<String, Future<BannerArt?>> _pictures = {};

  /// The picture of [itemId], fetched once. Null if there is none.
  Future<BannerArt?> artOf(String itemId) => _pictures[itemId] ??= repository
      .bannerArt(itemId)
      .then<BannerArt?>((art) => art)
      .catchError((Object _) {
        // Not on sale any more, or no connection: show the plain banner. Forget
        // it so a later try can succeed.
        _pictures.remove(itemId);
        return null;
      });
}

/// Makes the [ContestArtCache] available below. Without one, a painting-banner
/// shows as the plain banner instead. Pages pushed on the navigator are not below
/// the shell, so they need their own scope (with the same cache).
class ContestArtScope extends InheritedWidget {
  const ContestArtScope({required this.cache, required super.child, super.key});

  final ContestArtCache cache;

  static ContestArtCache? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ContestArtScope>()?.cache;

  /// [page] with the same pictures available as in [context].
  static Widget carry(BuildContext context, Widget page) {
    final cache = maybeOf(context);
    return cache == null ? page : ContestArtScope(cache: cache, child: page);
  }

  @override
  bool updateShouldNotify(ContestArtScope oldWidget) =>
      cache != oldWidget.cache;
}

/// Ids of painting-banners start with this.
const contestBannerPrefix = 'contest_';

bool isContestBanner(String? id) =>
    id != null && id.startsWith(contestBannerPrefix);

/// A banner made of a winning painting: the square painting is repeated across the
/// banner, every other copy mirrored so the copies join up.
class ContestBannerView extends StatelessWidget {
  const ContestBannerView({
    required this.itemId,
    required this.fallback,
    super.key,
  });

  final String itemId;

  /// Shown while the picture loads, or when there is none.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final cache = ContestArtScope.maybeOf(context);
    if (cache == null) return fallback;
    return FutureBuilder<BannerArt?>(
      future: cache.artOf(itemId),
      builder: (context, snapshot) {
        final art = snapshot.data;
        if (art == null) return fallback;
        return Semantics(
          image: true,
          label: 'Banner tranh của nhóm ${art.groupName}',
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BannerArtPainter(art),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class BannerArtPainter extends CustomPainter {
  BannerArtPainter(this.art);

  final BannerArt art;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || art.width == 0 || art.height == 0) return;
    final tile = size.height;
    final cell = tile / art.height;
    final tileWidth = cell * art.width;
    final paint = Paint();
    final tiles = (size.width / tileWidth).ceil();
    for (var t = 0; t < tiles; t++) {
      final mirrored = t.isOdd;
      for (var y = 0; y < art.height; y++) {
        for (var x = 0; x < art.width; x++) {
          final index = art.pixels[y * art.width + x];
          paint.color = Color(
            art.palette[index < art.palette.length ? index : 0],
          );
          final column = mirrored ? art.width - 1 - x : x;
          canvas.drawRect(
            Rect.fromLTWH(
              t * tileWidth + column * cell,
              y * cell,
              cell + 0.5,
              cell + 0.5,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BannerArtPainter old) => old.art != art;
}
