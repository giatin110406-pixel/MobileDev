import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// The look of a photobooth strip.
///
/// Every frame keeps the app's soul: cream paper, thick black outlines, hard
/// shadows, the yellow / teal / coral palette, Space Grotesk and little
/// four-pointed sparkles. They differ in what they borrow around that.
enum StripStyle {
  /// A strip of black film: sprocket holes, frame numbers, a date stamp.
  classicDark,

  /// A paper strip from a mall booth: scrapbook tape, thin rules.
  classicLight,

  /// The app itself: yellow dot-grid, stickers, tilted photos with hard shadows.
  neo,

  /// A game screen: pixel frames, scanlines, blocky pixel type.
  pixel8bit,

  /// A museum wall: the photos framed in gold on the Starry Night.
  vanGogh,
}

/// What gets printed. Photos are square, and 2 inches is a square of a 2×6
/// inch strip or of a 4×6 inch sheet, so they fit both exactly:
///  * [strip2x6]: one strip, 3 photos in a column (1×3);
///  * [sheet4x6]: that strip twice side by side, as a photobooth prints it, to
///    be cut in half;
///  * [grid4x6]: one 4×6 sheet of 6 photos, 2 columns by 3 rows (2×3), no cutting.
enum StripPaper { strip2x6, sheet4x6, grid4x6 }

/// Everything that decides how a strip looks, besides its photos.
class StripSpec {
  const StripSpec({
    this.style = StripStyle.classicDark,
    this.paper = StripPaper.sheet4x6,
    this.title = '',
    this.subtitle = '',
  });

  final StripStyle style;
  final StripPaper paper;

  /// The big line under the photos (the album's name by default).
  final String title;

  /// The small line under it (the date by default).
  final String subtitle;

  StripSpec copyWith({
    StripStyle? style,
    StripPaper? paper,
    String? title,
    String? subtitle,
  }) => StripSpec(
    style: style ?? this.style,
    paper: paper ?? this.paper,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
  );
}

/// One strip at 300 dpi: 2 × 6 inches.
const stripWidth = 600;
const stripHeight = 1800;

/// The fewest and most photos on a print; a strip takes at most
/// [stripColumnPhotos] of them (the first ones).
const minStripPhotos = 2;
const maxStripPhotos = 6;
const stripColumnPhotos = 3;

/// The painting behind the Van Gogh strip.
const vanGoghBackdrop = 'assets/styles/van_gogh_starry_night.jpg';

/// Pictures a strip needs besides the photos (loaded once, see
/// [loadStripAssets]).
class StripAssets {
  const StripAssets({this.vanGogh});

  final ui.Image? vanGogh;
}

Future<StripAssets> loadStripAssets({AssetBundle? bundle}) async {
  try {
    final data = await (bundle ?? rootBundle).load(vanGoghBackdrop);
    return StripAssets(
      vanGogh: await decodeStripPhoto(data.buffer.asUint8List()),
    );
  } catch (_) {
    // No painting: the Van Gogh strip falls back to a painted night sky colour.
    return const StripAssets();
  }
}

/// A photo file as an image to draw.
Future<ui.Image> decodeStripPhoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Draws the print for [photos], 2 to 6 of them, in the
/// order given. Returns the picture at print size (or [scale] times that, one
/// strip only, for a small preview). A strip shows the first 3 photos; frames
/// left empty (fewer photos than frames) are cards with the app's name, in the
/// style of the frame.
Future<ui.Image> renderStrip(
  StripSpec spec,
  List<ui.Image> photos, {
  StripAssets assets = const StripAssets(),
  double scale = 1,
}) async {
  assert(photos.length >= minStripPhotos && photos.length <= maxStripPhotos);
  final grid = spec.paper == StripPaper.grid4x6;
  final used = photos.take(grid ? maxStripPhotos : stripColumnPhotos).toList();
  // The 8-bit frame sets its words in pixels: made first, as small images.
  final pixelWords = spec.style == StripStyle.pixel8bit
      ? {
          'title': await _pixelWord(spec.title.toUpperCase(), 12),
          'subtitle': await _pixelWord(spec.subtitle, 9),
          'brand': await _pixelWord('POCKET PORTRAIT', 7),
        }
      : const <String, ui.Image?>{};
  final strip = await _paint(
    (stripWidth * (grid ? 2 : 1) * scale).round(),
    (stripHeight * scale).round(),
    (canvas) {
      if (scale != 1) canvas.scale(scale);
      _StripPainter(
        spec,
        used,
        assets,
        pixelWords,
        columns: grid ? 2 : 1,
      ).paint(canvas);
    },
  );
  for (final word in pixelWords.values) {
    word?.dispose();
  }
  // A scaled picture is a preview of one strip, not for printing.
  if (spec.paper != StripPaper.sheet4x6 || scale != 1) return strip;
  final sheet = await _paint(stripWidth * 2, stripHeight, (canvas) {
    canvas.drawImage(strip, Offset.zero, Paint());
    canvas.drawImage(strip, const Offset(stripWidth * 1.0, 0), Paint());
    // Where to cut: a small tick at the top and the bottom edge.
    final tick = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 2;
    for (final y in [0.0, stripHeight * 1.0]) {
      final dy = y == 0 ? 14.0 : -14.0;
      canvas.drawLine(
        Offset(stripWidth * 1.0, y),
        Offset(stripWidth * 1.0, y + dy),
        tick,
      );
    }
  });
  strip.dispose();
  return sheet;
}

/// [image] as PNG bytes (lossless: the text stays sharp when printed).
Future<Uint8List> stripPng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image> _paint(int width, int height, void Function(Canvas) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  draw(canvas);
  return recorder.endRecording().toImage(width, height);
}

/// [text] set small and cut to hard pixels (white on clear), to be drawn big
/// without smoothing: type that looks made of squares.
Future<ui.Image?> _pixelWord(String text, double fontSize) async {
  if (text.isEmpty) return null;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: NeoFont.display,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFFFFFFF),
        letterSpacing: 0.6,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = painter.width.ceil() + 2;
  final height = painter.height.ceil() + 2;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Offset(1, 1));
  final soft = await recorder.endRecording().toImage(width, height);
  final data = (await soft.toByteData())!;
  soft.dispose();
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    if (data.getUint8(i * 4 + 3) > 110) {
      bytes.fillRange(i * 4, i * 4 + 4, 255);
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

class _StripPainter {
  _StripPainter(
    this.spec,
    this.photos,
    this.assets,
    this.pixelWords, {
    this.columns = 1,
  });

  final StripSpec spec;
  final List<ui.Image> photos;
  final StripAssets assets;
  final Map<String, ui.Image?> pixelWords;

  /// 1 for a strip, 2 for the 4×6 sheet of six photos.
  final int columns;
  double get _w => stripWidth * columns * 1.0;
  static const _h = stripHeight * 1.0;

  static const _ink = NeoColors.ink;
  static const _cream = Color(0xFFF8EED2);

  /// Where the photos go: always 3 rows of SQUARES, like the app's own photos,
  /// in 1 or 2 columns. They are as big as the [side] margins and the room
  /// between [top] and the [footer] left for the words allow; any room over
  /// goes into the gaps (up to a point) and the block is centred.
  List<Rect> _slots({
    required double side,
    required double top,
    required double gap,
    required double footer,
  }) {
    const rows = 3;
    final room = _h - top - footer;
    final size = math.min(
      (_w - side * 2 - gap * (columns - 1)) / columns,
      (room - gap * (rows - 1)) / rows,
    );
    final spacing = math.min(gap * 2.2, (room - size * rows) / (rows - 1));
    final blockHeight = size * rows + spacing * (rows - 1);
    final blockWidth = size * columns + spacing * (columns - 1);
    final startY = top + (room - blockHeight) / 2;
    final startX = (_w - blockWidth) / 2;
    return [
      for (var i = 0; i < rows * columns; i++)
        Rect.fromLTWH(
          startX + (i % columns) * (size + spacing),
          startY + (i ~/ columns) * (size + spacing),
          size,
          size,
        ),
    ];
  }

  void paint(Canvas canvas) {
    switch (spec.style) {
      case StripStyle.classicDark:
        _film(canvas);
      case StripStyle.classicLight:
        _booth(canvas);
      case StripStyle.neo:
        _neo(canvas);
      case StripStyle.pixel8bit:
        _pixel(canvas);
      case StripStyle.vanGogh:
        _vanGogh(canvas);
    }
  }

  // ---- Film: black film with sprocket holes ------------------------------------

  void _film(Canvas canvas) {
    const side = 78.0;
    const footerHeight = 300.0;
    const film = Color(0xFF0E0E0E);
    const edge = Color(0xFFF1EBDD);
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), Paint()..color = film);
    _grain(
      canvas,
      Rect.fromLTWH(0, 0, _w, _h),
      const Color(0x0DFFFFFF),
      2600,
      3,
    );

    // Sprocket holes down both edges, the whole length like real film.
    final hole = Paint()..color = edge;
    for (var y = 22.0; y < _h - 20; y += 60) {
      for (final x in [side / 2 - 12, _w - side / 2 - 12 + 2]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 2, y, 28, 38),
            const Radius.circular(8),
          ),
          hole,
        );
      }
    }

    final slots = _slots(
      side: side + 8,
      top: 44,
      gap: 16,
      footer: footerHeight,
    );
    for (final (i, slot) in slots.indexed) {
      final round = RRect.fromRectAndRadius(slot, const Radius.circular(6));
      canvas.save();
      canvas.clipRRect(round);
      _fill(canvas, i, slot);
      canvas.restore();
      canvas.drawRRect(
        round,
        Paint()
          ..color = const Color(0x33F1EBDD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // Edge print between the holes and the photo, like a film's own marks:
      // once a row, not once a photo.
      if (i % columns != 0) continue;
      final mid = slot.center.dy;
      _sideways(
        canvas,
        '▸ ${24 - i ~/ columns}',
        Offset(side - 6, mid),
        size: 15,
        color: NeoColors.accent,
        angle: -math.pi / 2,
        spacing: 2,
      );
      _sideways(
        canvas,
        'POCKET PORTRAIT 400',
        Offset(_w - side + 6, mid),
        size: 13,
        color: NeoColors.accent.withValues(alpha: 0.75),
        angle: math.pi / 2,
        spacing: 3,
      );
    }

    final footer = Rect.fromLTWH(0, _h - footerHeight, _w, footerHeight);
    _text(
      canvas,
      spec.title,
      Offset(_w / 2, footer.top + 100),
      size: 54,
      color: edge,
      maxWidth: _w - 200,
      spacing: 0.5,
    );
    // A coral squiggle under it, drawn by hand.
    final squiggle = Path()..moveTo(_w / 2 - 110, footer.top + 152);
    for (var i = 0; i < 11; i++) {
      squiggle.relativeQuadraticBezierTo(10, i.isEven ? -12 : 12, 20, 0);
    }
    canvas.drawPath(
      squiggle,
      Paint()
        ..color = NeoColors.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // The date, like the stamp early digital cameras burned into a corner.
    _text(
      canvas,
      spec.subtitle,
      Offset(_w / 2, footer.top + 200),
      size: 26,
      color: NeoColors.coral,
      weight: FontWeight.w500,
      spacing: 5,
    );
    // Sparkles at the ends of the squiggle, clear of the title.
    _sparkle(
      canvas,
      Offset(_w / 2 - 150, footer.top + 152),
      16,
      NeoColors.accent,
    );
    _sparkle(
      canvas,
      Offset(_w / 2 + 150, footer.top + 152),
      16,
      NeoColors.accent,
    );
    _text(
      canvas,
      'POCKET PORTRAIT',
      Offset(_w / 2, _h - 44),
      size: 13,
      color: edge.withValues(alpha: 0.45),
      spacing: 6,
    );
  }

  // ---- Booth: a paper strip with scrapbook tape ------------------------------------

  void _booth(Canvas canvas) {
    const side = 52.0;
    const paper = Color(0xFFFFFBEF);
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), Paint()..color = paper);
    _grain(
      canvas,
      Rect.fromLTWH(0, 0, _w, _h),
      const Color(0x0F000000),
      1800,
      5,
    );
    final slots = _slots(side: side, top: 56, gap: 36, footer: 310);
    for (final (i, slot) in slots.indexed) {
      canvas.drawRect(slot.inflate(7), Paint()..color = _ink);
      canvas.drawRect(slot.inflate(3), Paint()..color = paper);
      _fill(canvas, i, slot);
    }
    // Tape holding the first and the last photo down.
    _tape(
      canvas,
      Offset(slots.first.left + 20, slots.first.top - 2),
      NeoColors.coral,
      -0.5,
    );
    _tape(
      canvas,
      Offset(slots.first.right - 22, slots.first.top - 2),
      NeoColors.teal,
      0.5,
    );
    _tape(
      canvas,
      Offset(slots.last.right - 20, slots.last.bottom + 2),
      NeoColors.accent,
      -0.5,
    );

    final footer = Rect.fromLTWH(0, _h - 310, _w, 310);
    // Two thin rules, with the date between them.
    final rule = Paint()
      ..color = _ink
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(side, footer.top + 56),
      Offset(_w - side, footer.top + 56),
      rule,
    );
    _text(
      canvas,
      spec.title,
      Offset(_w / 2, footer.top + 124),
      size: 56,
      color: _ink,
      maxWidth: _w - side * 2 - 20,
    );
    canvas.drawLine(
      Offset(side, footer.top + 184),
      Offset(_w - side, footer.top + 184),
      rule,
    );
    _text(
      canvas,
      spec.subtitle,
      Offset(_w / 2, footer.top + 226),
      size: 26,
      color: NeoColors.muted,
      weight: FontWeight.w500,
      spacing: 4,
    );
    _sparkle(canvas, Offset(side + 6, footer.top + 124), 15, NeoColors.coral);
    _sparkle(
      canvas,
      Offset(_w - side - 6, footer.top + 124),
      15,
      NeoColors.teal,
    );
    _text(
      canvas,
      'POCKET PORTRAIT',
      Offset(_w / 2, _h - 40),
      size: 13,
      color: NeoColors.muted,
      spacing: 6,
    );
  }

  // ---- Neo: the app itself -------------------------------------------------------

  void _neo(Canvas canvas) {
    const side = 56.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = NeoColors.accent,
    );
    // A grid of dots, like the app's paper.
    final dot = Paint()..color = const Color(0x2E000000);
    for (var y = 20.0; y < _h; y += 36) {
      for (var x = 20.0; x < _w; x += 36) {
        canvas.drawCircle(Offset(x, y), 3, dot);
      }
    }
    final slots = _slots(side: side, top: 62, gap: 34, footer: 330);
    const tilts = [-1.8, 1.5, -1.2, 1.8];
    const stickers = [
      NeoColors.coral,
      NeoColors.teal,
      NeoColors.surface,
      NeoColors.coral,
    ];
    for (final (i, slot) in slots.indexed) {
      final box = slot.deflate(14);
      final round = RRect.fromRectAndRadius(box, const Radius.circular(14));
      canvas.save();
      canvas.translate(box.center.dx, box.center.dy);
      canvas.rotate(tilts[i % tilts.length] * math.pi / 180);
      canvas.translate(-box.center.dx, -box.center.dy);
      canvas.drawRRect(
        round.shift(const Offset(12, 12)),
        Paint()..color = _ink,
      );
      canvas.save();
      canvas.clipRRect(round);
      _fill(canvas, i, box);
      canvas.restore();
      canvas.drawRRect(
        round,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      // A round number sticker on a corner, switching sides.
      final corner = i.isEven
          ? box.topLeft + const Offset(4, 4)
          : box.topRight + const Offset(-4, 4);
      _numberSticker(canvas, corner, '${i + 1}', stickers[i % stickers.length]);
      canvas.restore();
    }
    final footer = Rect.fromLTWH(0, _h - 330, _w, 330);
    // The title on a label with a hard shadow.
    final label = RRect.fromRectAndRadius(
      Rect.fromLTWH(side, footer.top + 36, _w - side * 2 - 12, 118),
      const Radius.circular(16),
    );
    canvas.drawRRect(label.shift(const Offset(12, 12)), Paint()..color = _ink);
    canvas.drawRRect(label, Paint()..color = NeoColors.surface);
    canvas.drawRRect(
      label,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    _text(
      canvas,
      spec.title,
      label.center,
      size: 50,
      color: _ink,
      maxWidth: label.width - 40,
    );
    // The date on a teal sticker, a little crooked.
    canvas.save();
    canvas.translate(_w / 2 + 40, footer.top + 232);
    canvas.rotate(-0.045);
    final date = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 360, height: 58),
      const Radius.circular(29),
    );
    canvas.drawRRect(date.shift(const Offset(6, 6)), Paint()..color = _ink);
    canvas.drawRRect(date, Paint()..color = NeoColors.teal);
    canvas.drawRRect(
      date,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _text(
      canvas,
      spec.subtitle,
      Offset.zero,
      size: 26,
      color: _ink,
      maxWidth: 320,
      spacing: 1,
    );
    canvas.restore();
    _sparkle(canvas, Offset(side + 24, footer.top + 232), 24, _ink);
    _sparkle(
      canvas,
      Offset(_w - side - 12, footer.top + 190),
      18,
      NeoColors.coral,
    );
    _text(
      canvas,
      'POCKET PORTRAIT',
      Offset(_w / 2, _h - 38),
      size: 14,
      color: _ink,
      spacing: 6,
    );
  }

  void _numberSticker(Canvas canvas, Offset center, String text, Color color) {
    canvas.drawCircle(center + const Offset(4, 4), 26, Paint()..color = _ink);
    canvas.drawCircle(center, 26, Paint()..color = color);
    canvas.drawCircle(
      center,
      26,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _text(canvas, text, center, size: 28, color: _ink);
  }

  // ---- 8-bit: a game screen ---------------------------------------------------------

  void _pixel(Canvas canvas) {
    const night = Color(0xFF1B1446);
    const block = 8.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), Paint()..color = night);
    // Square stars, always in the same places.
    final random = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 60; i++) {
      final size = random.nextBool() ? 6.0 : 4.0;
      final x = (random.nextDouble() * _w / 4).floorToDouble() * 4;
      final y = (random.nextDouble() * _h / 4).floorToDouble() * 4;
      // None where the words go.
      if (y > _h - 330) continue;
      star.color = [
        NeoColors.accent,
        NeoColors.teal,
        const Color(0xFFFFFFFF),
      ][i % 3];
      canvas.drawRect(Rect.fromLTWH(x, y, size, size), star);
    }
    // A marquee of squares round the edge, like an arcade cabinet.
    final marquee = Paint();
    for (var i = 0; i * 24.0 < _w; i++) {
      marquee.color = i.isEven ? NeoColors.accent : NeoColors.coral;
      canvas.drawRect(Rect.fromLTWH(i * 24.0, 0, 24, 12), marquee);
      canvas.drawRect(Rect.fromLTWH(i * 24.0, _h - 12, 24, 12), marquee);
    }
    for (var i = 0; i * 24.0 < _h; i++) {
      marquee.color = i.isEven ? NeoColors.accent : NeoColors.coral;
      canvas.drawRect(Rect.fromLTWH(0, i * 24.0, 12, 24), marquee);
      canvas.drawRect(Rect.fromLTWH(_w - 12, i * 24.0, 12, 24), marquee);
    }

    final slots = _slots(side: 50, top: 50, gap: 26, footer: 320);
    for (final (i, slot) in slots.indexed) {
      // A hard black shadow, then yellow and black stepped frames.
      canvas.drawRect(
        slot.shift(const Offset(block, block)),
        Paint()..color = const Color(0xFF0A0624),
      );
      _pixelFrame(canvas, slot, block, NeoColors.accent);
      _pixelFrame(canvas, slot.deflate(block), block, _ink);
      final photo = slot.deflate(block * 2);
      _fill(canvas, i, photo);
      // Scanlines over the picture, like a screen.
      final lines = Paint()..color = const Color(0x1F000000);
      for (var y = photo.top; y < photo.bottom; y += 6) {
        canvas.drawRect(Rect.fromLTWH(photo.left, y, photo.width, 2), lines);
      }
      _pixelPlus(
        canvas,
        photo.topRight + const Offset(-26, 26),
        NeoColors.accent,
      );
    }

    final footer = Rect.fromLTWH(0, _h - 320, _w, 320);
    // The title in pixel type, with a coral copy shifted behind it.
    final title = pixelWords['title'];
    if (title != null) {
      final scale = (_w - 120) ~/ title.width;
      final at = Offset(_w / 2, footer.top + 100);
      _drawPixelWord(
        canvas,
        title,
        at + const Offset(6, 6),
        scale.clamp(2, 6).toDouble(),
        NeoColors.coral,
      );
      _drawPixelWord(
        canvas,
        title,
        at,
        scale.clamp(2, 6).toDouble(),
        NeoColors.accent,
      );
    }
    final subtitle = pixelWords['subtitle'];
    if (subtitle != null) {
      _drawPixelWord(
        canvas,
        subtitle,
        Offset(_w / 2, footer.top + 188),
        ((_w - 160) ~/ subtitle.width).clamp(2, 4).toDouble(),
        NeoColors.teal,
      );
    }
    final brand = pixelWords['brand'];
    if (brand != null) {
      _drawPixelWord(
        canvas,
        brand,
        Offset(_w / 2, _h - 58),
        3,
        const Color(0xFFFFFFFF),
      );
    }
    _pixelHeart(canvas, Offset(60, _h - 112), NeoColors.coral);
    _pixelHeart(canvas, Offset(_w - 60 - 35, _h - 112), NeoColors.coral);
  }

  /// A square ring [block] thick round [rect], without its corner blocks.
  void _pixelFrame(Canvas canvas, Rect rect, double block, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left + block,
        rect.top,
        rect.right - block,
        rect.top + block,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left + block,
        rect.bottom - block,
        rect.right - block,
        rect.bottom,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left,
        rect.top + block,
        rect.left + block,
        rect.bottom - block,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        rect.right - block,
        rect.top + block,
        rect.right,
        rect.bottom - block,
      ),
      paint,
    );
  }

  void _pixelHeart(Canvas canvas, Offset at, Color color, [double cell = 5.0]) {
    const rows = [
      '.XX.XX.',
      'XXXXXXX',
      'XXXXXXX',
      '.XXXXX.',
      '..XXX..',
      '...X...',
    ];
    final paint = Paint()..color = color;
    for (final (y, row) in rows.indexed) {
      for (var x = 0; x < row.length; x++) {
        if (row[x] == 'X') {
          canvas.drawRect(
            Rect.fromLTWH(at.dx + x * cell, at.dy + y * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  /// A little plus-shaped glint made of squares.
  void _pixelPlus(Canvas canvas, Offset center, Color color) {
    final paint = Paint()..color = color;
    for (final d in const [
      Offset(0, 0),
      Offset(-8, 0),
      Offset(8, 0),
      Offset(0, -8),
      Offset(0, 8),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: center + d, width: 8, height: 8),
        paint,
      );
    }
  }

  void _drawPixelWord(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double scale,
    Color color,
  ) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: center,
        width: image.width * scale,
        height: image.height * scale,
      ),
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  // ---- Van Gogh: a museum wall --------------------------------------------------------

  static const _gold = Color(0xFFC9A23A);
  static const _goldDark = Color(0xFF7A5C14);
  static const _navy = Color(0xFF1D2E5C);

  void _vanGogh(Canvas canvas) {
    final full = Rect.fromLTWH(0, 0, _w, _h);
    final painting = assets.vanGogh;
    if (painting != null) {
      paintImage(
        canvas: canvas,
        rect: full,
        image: painting,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else {
      canvas.drawRect(full, Paint()..color = const Color(0xFF1D3F8F));
    }
    // A dark veil at the edges, so the frames glow.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          radius: 1.1,
          colors: [Color(0x00000000), Color(0x80000000)],
        ).createShader(full),
    );
    // The whole strip is a framed canvas: a gold border with studs at the corners.
    final outer = full.deflate(14);
    canvas.drawRect(
      outer,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    canvas.drawRect(
      outer.deflate(7),
      Paint()
        ..color = _goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRect(
      outer.inflate(7),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final corner in [
      outer.topLeft,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomRight,
    ]) {
      canvas.drawCircle(corner, 14, Paint()..color = _gold);
      canvas.drawCircle(
        corner,
        14,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final slots = _slots(side: 58, top: 62, gap: 30, footer: 330);
    for (final (i, slot) in slots.indexed) {
      // Hung on the wall: a soft drop shadow, a gold frame, a cream mount.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          slot.shift(const Offset(0, 9)),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0x77000000),
      );
      canvas.drawRect(slot, Paint()..color = _gold);
      canvas.drawRect(
        slot.deflate(3),
        Paint()
          ..color = _goldDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawRect(slot.deflate(11), Paint()..color = _cream);
      final photo = slot.deflate(22);
      _fill(canvas, i, photo);
      canvas.drawRect(
        photo,
        Paint()
          ..color = _goldDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawRect(
        slot,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    // A museum label: cream card, gold rule, the title and the date.
    final footer = Rect.fromLTWH(0, _h - 330, _w, 330);
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(70, footer.top + 52, _w - 140 - 10, 196),
      const Radius.circular(6),
    );
    canvas.drawRRect(card.shift(const Offset(8, 8)), Paint()..color = _ink);
    canvas.drawRRect(card, Paint()..color = _cream);
    canvas.drawRRect(
      card,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawRRect(
      card.deflate(10),
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _text(
      canvas,
      spec.title,
      Offset(card.center.dx, card.top + 66),
      size: 44,
      color: _navy,
      maxWidth: card.width - 60,
    );
    canvas.drawLine(
      Offset(card.center.dx - 60, card.top + 108),
      Offset(card.center.dx + 60, card.top + 108),
      Paint()
        ..color = _gold
        ..strokeWidth = 3,
    );
    _text(
      canvas,
      spec.subtitle,
      Offset(card.center.dx, card.top + 138),
      size: 22,
      color: const Color(0xFF5B4A24),
      weight: FontWeight.w500,
      spacing: 2,
    );
    _text(
      canvas,
      'POCKET PORTRAIT',
      Offset(card.center.dx, card.top + 172),
      size: 12,
      color: _goldDark,
      spacing: 6,
    );
    _sparkle(canvas, Offset(card.left + 34, card.center.dy), 14, _gold);
    _sparkle(canvas, Offset(card.right - 34, card.center.dy), 14, _gold);
  }

  // ---- Shared pieces --------------------------------------------------------------------

  /// What goes in slot [i]: the photo, or (with fewer than three photos) a card
  /// with the app's name, in the manner of the frame.
  void _fill(Canvas canvas, int i, Rect rect) {
    if (i < photos.length) {
      _photo(canvas, photos[i], rect);
      return;
    }
    final c = rect.center;
    final u = rect.width;
    switch (spec.style) {
      case StripStyle.classicDark:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF1A1A1A));
        _sparkle(canvas, c.translate(0, -u * 0.17), u * 0.17, NeoColors.accent);
        _text(
          canvas,
          'POCKET',
          c.translate(0, u * 0.1),
          size: u * 0.13,
          color: const Color(0xFFF1EBDD),
          spacing: 6,
        );
        _text(
          canvas,
          'PORTRAIT',
          c.translate(0, u * 0.25),
          size: u * 0.13,
          color: const Color(0xFFF1EBDD),
          spacing: 6,
        );
      case StripStyle.classicLight:
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFBEF));
        _sparkle(canvas, c.translate(0, -u * 0.17), u * 0.17, NeoColors.coral);
        _sparkle(
          canvas,
          rect.topLeft.translate(u * 0.12, u * 0.12),
          u * 0.05,
          NeoColors.teal,
        );
        _sparkle(
          canvas,
          rect.bottomRight.translate(-u * 0.12, -u * 0.12),
          u * 0.05,
          NeoColors.accent,
        );
        _text(
          canvas,
          'POCKET',
          c.translate(0, u * 0.1),
          size: u * 0.13,
          color: _ink,
          spacing: 5,
        );
        _text(
          canvas,
          'PORTRAIT',
          c.translate(0, u * 0.25),
          size: u * 0.13,
          color: _ink,
          spacing: 5,
        );
      case StripStyle.neo:
        canvas.drawRect(rect, Paint()..color = NeoColors.teal);
        _sparkle(canvas, c.translate(0, -u * 0.17), u * 0.2, _ink);
        _sparkle(
          canvas,
          c.translate(u * 0.24, -u * 0.3),
          u * 0.07,
          NeoColors.coral,
        );
        _text(
          canvas,
          'POCKET',
          c.translate(0, u * 0.1),
          size: u * 0.14,
          color: _ink,
          spacing: 3,
        );
        _text(
          canvas,
          'PORTRAIT',
          c.translate(0, u * 0.26),
          size: u * 0.14,
          color: _ink,
          spacing: 3,
        );
      case StripStyle.pixel8bit:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF2A1F6B));
        _pixelHeart(
          canvas,
          c.translate(-u * 0.25, -u * 0.34),
          NeoColors.coral,
          u * 0.5 / 7,
        );
        _pixelPlus(
          canvas,
          rect.topLeft.translate(u * 0.14, u * 0.14),
          NeoColors.accent,
        );
        _pixelPlus(
          canvas,
          rect.bottomRight.translate(-u * 0.14, -u * 0.14),
          NeoColors.teal,
        );
        final brand = pixelWords['brand'];
        if (brand != null) {
          _drawPixelWord(
            canvas,
            brand,
            c.translate(0, u * 0.24),
            (u * 0.82 / brand.width).floorToDouble().clamp(1, 6),
            const Color(0xFFFFFFFF),
          );
        }
      case StripStyle.vanGogh:
        // A piece of the painting itself, in the gold frame.
        final painting = assets.vanGogh;
        if (painting != null) {
          paintImage(
            canvas: canvas,
            rect: rect,
            image: painting,
            fit: BoxFit.cover,
            alignment: const Alignment(0.25, -0.35),
            filterQuality: FilterQuality.high,
          );
        } else {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF1D3F8F));
        }
        _sparkle(canvas, c, u * 0.11, const Color(0xFFFFE66D));
    }
  }

  /// [image] filling [slot], centre-cropped.
  void _photo(Canvas canvas, ui.Image image, Rect slot) {
    paintImage(
      canvas: canvas,
      rect: slot,
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  /// One line centred on [center], shrunk to fit [maxWidth].
  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w700,
    double maxWidth = stripWidth * 1.0,
    double spacing = 0,
  }) {
    if (text.isEmpty) return;
    var fontSize = size;
    late TextPainter painter;
    while (true) {
      painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: NeoFont.display,
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            letterSpacing: spacing,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width <= maxWidth || fontSize <= 12) break;
      fontSize -= 2;
    }
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  /// A short line running along an edge, centred on [center]; [angle] turns it.
  void _sideways(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    required Color color,
    required double angle,
    double spacing = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    _text(
      canvas,
      text,
      Offset.zero,
      size: size,
      color: color,
      weight: FontWeight.w500,
      maxWidth: 300,
      spacing: spacing,
    );
    canvas.restore();
  }

  /// A four-pointed sparkle.
  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.28;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  /// A strip of washi tape across [at], turned by [angle] radians.
  void _tape(Canvas canvas, Offset at, Color color, double angle) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: 120, height: 38);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.82));
    // Torn ends.
    final torn = Paint()..color = const Color(0xFFFFFBEF);
    for (final side in [-1.0, 1.0]) {
      final x = side * 60;
      final path = Path()..moveTo(x, -19);
      for (var i = 0; i < 6; i++) {
        path.lineTo(x - side * (i.isEven ? 7 : 0), -19 + (i + 1) * 38 / 6);
      }
      path.lineTo(x + side * 8, 19);
      path.lineTo(x + side * 8, -19);
      canvas.drawPath(path..close(), torn);
    }
    canvas.restore();
  }

  /// Fine specks, always the same ones, for a printed-paper feel.
  void _grain(Canvas canvas, Rect area, Color color, int count, int seed) {
    final random = math.Random(seed);
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          area.left + random.nextDouble() * area.width,
          area.top + random.nextDouble() * area.height,
          random.nextBool() ? 2 : 3,
          2,
        ),
        paint,
      );
    }
  }
}
