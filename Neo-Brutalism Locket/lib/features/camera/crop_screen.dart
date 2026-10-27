import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';

/// A gallery photo, upright and scaled down, ready to be framed by the user.
class CropSource {
  const CropSource(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Longest side of the photo shown in the crop screen.
const _cropMaxSide = 2048;

/// Decodes [bytes] (EXIF orientation applied) and scales it to at most
/// [_cropMaxSide]; runs in an isolate.
CropSource prepareCropSource(Uint8List bytes) {
  var image = decodeOrientedImage(bytes);
  final longest = math.max(image.width, image.height);
  if (longest > _cropMaxSide) {
    final scale = _cropMaxSide / longest;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return CropSource(
    Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    image.width,
    image.height,
  );
}

/// The square at ([x], [y], [side]) of [CropSource.bytes] as a JPEG capped at
/// [uploadMaxSide].
class CropRequest {
  const CropRequest(this.bytes, this.x, this.y, this.side);

  final Uint8List bytes;
  final int x;
  final int y;
  final int side;
}

Uint8List cropSquareAt(CropRequest request) {
  final image = img.decodeImage(request.bytes)!;
  final side = math.min(
    request.side,
    math.min(image.width - request.x, image.height - request.y),
  );
  var square = img.copyCrop(
    image,
    x: request.x,
    y: request.y,
    width: side,
    height: side,
  );
  if (side > uploadMaxSide) {
    square = img.copyResize(
      square,
      width: uploadMaxSide,
      height: uploadMaxSide,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(square, quality: 92));
}

/// A photo the user drags and zooms under the square frame it fills: the
/// shoot page puts it where the viewfinder was. [CropFrameState.crop] returns
/// the square currently framed as JPEG bytes.
class CropFrame extends StatefulWidget {
  const CropFrame({required this.source, super.key});

  final CropSource source;

  @override
  State<CropFrame> createState() => CropFrameState();
}

class CropFrameState extends State<CropFrame> {
  final _controller = TransformationController();
  double _viewport = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scale that makes the photo just cover the square frame.
  double get _cover =>
      _viewport / math.min(widget.source.width, widget.source.height);

  /// Puts the photo back in the middle, zoomed out as far as it goes.
  void reset() {
    final s = _cover;
    final dx = (widget.source.width * s - _viewport) / 2;
    final dy = (widget.source.height * s - _viewport) / 2;
    _controller.value = Matrix4.identity()..translateByDouble(-dx, -dy, 0, 1);
  }

  Future<Uint8List> crop() {
    final m = _controller.value;
    final t = m.getTranslation();
    // Frame position in the photo's own pixels.
    final k = _cover * m.getMaxScaleOnAxis();
    final side = (_viewport / k).round();
    final x = (-t.x / k).round().clamp(0, widget.source.width - 1);
    final y = (-t.y / k).round().clamp(0, widget.source.height - 1);
    return compute(cropSquareAt, CropRequest(widget.source.bytes, x, y, side));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        if (side != _viewport) {
          _viewport = side;
          WidgetsBinding.instance.addPostFrameCallback((_) => reset());
        }
        final s = _cover;
        return InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: 1,
          maxScale: 6,
          boundaryMargin: EdgeInsets.zero,
          child: Image.memory(
            widget.source.bytes,
            width: widget.source.width * s,
            height: widget.source.height * s,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
