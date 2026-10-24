import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/strip/strip_render.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

/// A photo to put on the strip: the picture as posted and, when the author sent
/// it, the shot before its style.
class StripPhoto {
  const StripPhoto({required this.path, this.originalPath});

  final String path;
  final String? originalPath;
}

/// Fetches a file from the `media` bucket. Null when it cannot be had.
typedef StripFileLoader = Future<Uint8List?> Function(String path);

/// Uses the pictures the grid already downloaded (same cache key as
/// RemoteImage), so opening the studio rarely downloads anything.
StripFileLoader cachedMediaLoader(MediaUrls urls) => (path) async {
  final url = await urls.resolve('media', path);
  if (url == null) return null;
  try {
    final file = await DefaultCacheManager().getSingleFile(
      url,
      key: 'media/$path',
    );
    return await file.readAsBytes();
  } catch (e, st) {
    AppLog.warn('strip', e, st);
    return null;
  }
};

/// How big the little previews of each frame are drawn (a share of print size).
const _thumbScale = 0.4;

/// Turns 2 to 4 photos into a photobooth strip: look through the frames (each
/// shown on your own photos), pick the paper, change the words, then save it or
/// send it to a printer. The file is made at print size (300 dpi), as one 2×6
/// strip or a 4×6 sheet of two.
class StripStudioScreen extends StatefulWidget {
  const StripStudioScreen({
    super.key,
    required this.photos,
    required this.title,
    required this.subtitle,
    this.loader,
    this.assets,
  });

  final List<StripPhoto> photos;

  /// The words the strip starts with (the album's name and dates).
  final String title;
  final String subtitle;

  /// Null: from the [MediaUrlsScope] above, through the picture cache.
  final StripFileLoader? loader;

  /// Null: loaded from the app's assets.
  final Future<StripAssets> Function()? assets;

  @override
  State<StripStudioScreen> createState() => _StripStudioScreenState();
}

class _StripStudioScreenState extends State<StripStudioScreen> {
  // Four photos or more want the 2×3 sheet; up to three, the strip twice.
  late StripSpec _spec = StripSpec(
    paper: widget.photos.length > stripColumnPhotos
        ? StripPaper.grid4x6
        : StripPaper.sheet4x6,
    title: widget.title,
    subtitle: widget.subtitle,
  );
  late final _title = TextEditingController(text: widget.title);
  late final _subtitle = TextEditingController(text: widget.subtitle);
  bool _useOriginals = false;

  /// Decoded pictures by path (posted and originals, as they are asked for).
  final _images = <String, ui.Image>{};
  StripAssets _assets = const StripAssets();
  bool _failed = false;
  Uint8List? _png;
  final _thumbs = <StripStyle, Uint8List>{};
  bool _busy = false;
  int _generation = 0;
  int _thumbGeneration = 0;
  Timer? _typing;

  bool get _hasOriginals => widget.photos.any((p) => p.originalPath != null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _typing?.cancel();
    _generation++;
    _thumbGeneration++;
    _title.dispose();
    _subtitle.dispose();
    for (final image in _images.values) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    _assets = await (widget.assets ?? loadStripAssets)();
    await _render();
  }

  StripFileLoader? get _loader {
    final given = widget.loader;
    if (given != null) return given;
    final urls = MediaUrlsScope.maybeOf(context);
    return urls == null ? null : cachedMediaLoader(urls);
  }

  /// The pictures to draw, in order. Null when one could not be loaded.
  Future<List<ui.Image>?> _pictures() async {
    final loader = _loader;
    if (loader == null) return null;
    final pictures = <ui.Image>[];
    for (final photo in widget.photos) {
      final path = _useOriginals
          ? photo.originalPath ?? photo.path
          : photo.path;
      var image = _images[path];
      if (image == null) {
        final bytes = await loader(path);
        if (bytes == null) return null;
        try {
          image = await decodeStripPhoto(bytes);
        } catch (e, st) {
          AppLog.warn('strip', e, st);
          return null;
        }
        _images[path] = image;
      }
      pictures.add(image);
    }
    return pictures;
  }

  /// Draws the strip again; a newer request makes an older one give up.
  Future<void> _render() async {
    final generation = ++_generation;
    final pictures = await _pictures();
    if (!mounted || generation != _generation) return;
    if (pictures == null) {
      setState(() => _failed = true);
      return;
    }
    final image = await renderStrip(_spec, pictures, assets: _assets);
    final png = await stripPng(image);
    image.dispose();
    if (!mounted || generation != _generation) return;
    setState(() {
      _png = png;
      _failed = false;
    });
    unawaited(_renderThumbs(pictures));
  }

  /// A small picture of every frame on these photos, one after the other.
  Future<void> _renderThumbs(List<ui.Image> pictures) async {
    final generation = ++_thumbGeneration;
    for (final style in StripStyle.values) {
      final image = await renderStrip(
        StripSpec(
          style: style,
          paper: StripPaper.strip2x6,
          title: _spec.title,
          subtitle: _spec.subtitle,
        ),
        pictures,
        assets: _assets,
        scale: _thumbScale,
      );
      final png = await stripPng(image);
      image.dispose();
      if (!mounted || generation != _thumbGeneration) return;
      setState(() => _thumbs[style] = png);
    }
  }

  void _change(StripSpec spec) {
    setState(() => _spec = spec);
    _render();
  }

  /// Typing redraws once the person pauses.
  void _typed() {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 350), () {
      _change(_spec.copyWith(title: _title.text, subtitle: _subtitle.text));
    });
  }

  String get _fileName => 'strip_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _save() async {
    final png = _png;
    if (png == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await Gal.putImageBytes(png, name: _fileName);
      if (mounted) showNeoSnack(context, l10n.stripSaved);
    } catch (e, st) {
      AppLog.warn('strip', e, st);
      if (mounted) showNeoSnack(context, l10n.postSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final png = _png;
    if (png == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png, mimeType: 'image/png', name: '$_fileName.png'),
          ],
        ),
      );
    } catch (e, st) {
      AppLog.warn('strip', e, st);
      if (mounted) showNeoSnack(context, l10n.postShareFailed);
    }
  }

  /// The strip full screen, to pinch and look at the small print.
  void _zoom() {
    final png = _png;
    if (png == null) return;
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xE6000000),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(png, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  String _styleName(AppLocalizations l10n, StripStyle style) => switch (style) {
    StripStyle.classicDark => l10n.stripStyleClassicDark,
    StripStyle.classicLight => l10n.stripStyleClassicLight,
    StripStyle.neo => l10n.stripStyleNeo,
    StripStyle.pixel8bit => l10n.stripStylePixel,
    StripStyle.vanGogh => l10n.stripStyleVanGogh,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paper = _spec.paper;
    final wide = paper != StripPaper.strip2x6;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back,
                    tooltip: l10n.backTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.stripTitle,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _sizeTag(wide ? '10×15 CM' : '5×15 CM'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  _stage(l10n, wide),
                  const SizedBox(height: 18),
                  _label(l10n.stripFrameLabel),
                  _frames(l10n),
                  const SizedBox(height: 18),
                  _label(l10n.stripPaperLabel),
                  Row(
                    children: [
                      for (final (index, option) in [
                        (l10n.stripPaperSheet, StripPaper.sheet4x6),
                        (l10n.stripPaperStrip, StripPaper.strip2x6),
                        (l10n.stripPaperGrid, StripPaper.grid4x6),
                      ].indexed) ...[
                        if (index > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _paperCard(
                            label: option.$1,
                            selected: paper == option.$2,
                            paper: option.$2,
                            onTap: () =>
                                _change(_spec.copyWith(paper: option.$2)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (paper) {
                      StripPaper.sheet4x6 => l10n.stripPaperSheetHint,
                      StripPaper.strip2x6 => l10n.stripPaperStripHint,
                      StripPaper.grid4x6 => l10n.stripPaperGridHint,
                    },
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (paper != StripPaper.grid4x6 &&
                      widget.photos.length > stripColumnPhotos)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.stripOnlyThree(widget.photos.length),
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (_hasOriginals) ...[
                    const SizedBox(height: 14),
                    NeoSwitch(
                      value: _useOriginals,
                      label: l10n.stripUseOriginals,
                      onChanged: (value) {
                        setState(() => _useOriginals = value);
                        _render();
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  _label(l10n.stripTextLabel),
                  _field(_title, l10n.stripTitleLabel, 28),
                  const SizedBox(height: 10),
                  _field(_subtitle, l10n.stripSubtitleLabel, 32),
                ],
              ),
            ),
            _actionBar(l10n),
          ],
        ),
      ),
    );
  }

  // ---- The stage: the strip on a desk -------------------------------------------

  Widget _stage(AppLocalizations l10n, bool wide) {
    final png = _png;
    final height = MediaQuery.sizeOf(context).height * 0.46;
    return GestureDetector(
      onTap: _zoom,
      child: Container(
        height: height,
        decoration: NeoTheme.panel(color: NeoColors.accent, radius: 16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _DotsPainter()),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: AspectRatio(
                  aspectRatio: wide ? 2 / 3 : 1 / 3,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.94,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: png != null
                        ? Transform.rotate(
                            key: ValueKey(png),
                            angle: -0.02,
                            child: Container(
                              decoration: const BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: NeoColors.ink,
                                    offset: Offset(8, 8),
                                  ),
                                ],
                              ),
                              child: Image.memory(
                                png,
                                key: const ValueKey('strip-preview'),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          )
                        : Center(
                            key: const ValueKey('strip-wait'),
                            child: _failed
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      l10n.stripLoadFailed,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: NeoColors.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : const CircularProgressIndicator(
                                    color: NeoColors.ink,
                                  ),
                          ),
                  ),
                ),
              ),
            ),
            if (png != null)
              Positioned(
                left: 10,
                top: 10,
                child: _sizeTag(l10n.stripZoomHint, icon: Icons.zoom_in),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sizeTag(String text, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: NeoColors.surface,
      border: Border.all(color: NeoColors.ink, width: 2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: NeoColors.ink),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  // ---- The frames, each on your own photos ------------------------------------------

  Widget _frames(AppLocalizations l10n) => SizedBox(
    height: 166,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(right: 16, bottom: 6),
      itemCount: StripStyle.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final style = StripStyle.values[index];
        final selected = _spec.style == style;
        final thumb = _thumbs[style];
        return Semantics(
          button: true,
          selected: selected,
          label: _styleName(l10n, style),
          child: NeoPress(
            onTap: () => _change(_spec.copyWith(style: style)),
            offset: const Offset(3, 3),
            sunken: selected,
            builder: (context, pressed) => SizedBox(
              width: 92,
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 124,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: NeoColors.surface,
                      border: Border.all(
                        color: NeoColors.ink,
                        width: selected ? 4 : 2.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: NeoPress.shadow(
                        pressed,
                        offset: const Offset(3, 3),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumb != null)
                          Image.memory(
                            thumb,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            gaplessPlayback: true,
                          )
                        else
                          const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: NeoColors.muted,
                              size: 20,
                            ),
                          ),
                        if (selected)
                          const Positioned(
                            right: 5,
                            top: 5,
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: NeoColors.ink,
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: NeoColors.accent,
                                child: Icon(
                                  Icons.check,
                                  size: 13,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? NeoColors.accent : Colors.transparent,
                      border: Border.all(
                        color: selected ? NeoColors.ink : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _styleName(l10n, style),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  // ---- Paper -----------------------------------------------------------------------------

  Widget _paperCard({
    required String label,
    required bool selected,
    required StripPaper paper,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: NeoPress(
      onTap: onTap,
      offset: const Offset(3, 3),
      sunken: selected,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? NeoColors.accent : NeoColors.surface,
          border: Border.all(color: NeoColors.ink, width: 2.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: NeoPress.shadow(pressed, offset: const Offset(3, 3)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: CustomPaint(
                size: const Size(80, 54),
                painter: _PaperIconPainter(paper),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- Small parts ---------------------------------------------------------------------------

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        color: NeoColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label, int max) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: NeoTheme.panel(color: NeoColors.surface),
        child: TextField(
          controller: controller,
          maxLength: max,
          onChanged: (_) => _typed(),
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            counterText: '',
          ),
        ),
      );

  /// Save and print, always in reach at the bottom.
  Widget _actionBar(AppLocalizations l10n) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      color: NeoColors.paper,
      border: Border(top: BorderSide(color: NeoColors.ink, width: 2.5)),
    ),
    child: Row(
      children: [
        Expanded(
          child: NeoButton(
            expand: true,
            label: l10n.stripSave,
            icon: Icons.download_rounded,
            variant: NeoButtonVariant.primary,
            onPressed: _png == null || _busy ? null : _save,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NeoButton(
            expand: true,
            label: l10n.stripShare,
            icon: Icons.print_outlined,
            variant: NeoButtonVariant.outline,
            onPressed: _png == null ? null : _share,
          ),
        ),
      ],
    ),
  );
}

/// Little dots on the stage, like the app's paper.
class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x26000000);
    for (var y = 12.0; y < size.height; y += 22) {
      for (var x = 12.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// What is printed, drawn as an icon: one strip, two strips to cut apart, or a
/// grid of six.
class _PaperIconPainter extends CustomPainter {
  const _PaperIconPainter(this.paper);

  final StripPaper paper;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = paper == StripPaper.strip2x6 ? 1 : 2;
    final sheetWidth = columns == 2 ? 40.0 : 22.0;
    final left = (size.width - sheetWidth) / 2;
    final sheet = Rect.fromLTWH(left, 1, sheetWidth, size.height - 6);
    canvas.drawRect(
      sheet.shift(const Offset(3, 3)),
      Paint()..color = NeoColors.ink,
    );
    canvas.drawRect(sheet, Paint()..color = NeoColors.surface);
    final photo = Paint()..color = NeoColors.teal;
    final cell = sheetWidth / columns;
    final rowHeight = (size.height - 12) / 3;
    const inset = 3.0;
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < 3; r++) {
        canvas.drawRect(
          Rect.fromLTWH(
            left + c * cell + inset,
            4 + r * rowHeight,
            cell - inset * 2,
            rowHeight - 3,
          ),
          photo,
        );
      }
    }
    if (paper == StripPaper.sheet4x6) {
      // The cut between the two strips.
      final dash = Paint()
        ..color = NeoColors.coral
        ..strokeWidth = 2;
      for (var y = 0.0; y < size.height - 6; y += 6) {
        canvas.drawLine(
          Offset(sheet.center.dx, y + 1),
          Offset(sheet.center.dx, y + 4),
          dash,
        );
      }
    }
    canvas.drawRect(
      sheet,
      Paint()
        ..color = NeoColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PaperIconPainter oldDelegate) =>
      oldDelegate.paper != paper;
}

/// Opens the studio for [photos], keeping the way to storage.
void openStripStudio(
  BuildContext context, {
  required List<StripPhoto> photos,
  required String title,
  required String subtitle,
}) {
  final urls = MediaUrlsScope.maybeOf(context);
  final studio = StripStudioScreen(
    photos: photos,
    title: title,
    subtitle: subtitle,
  );
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          urls == null ? studio : MediaUrlsScope(urls: urls, child: studio),
    ),
  );
}
