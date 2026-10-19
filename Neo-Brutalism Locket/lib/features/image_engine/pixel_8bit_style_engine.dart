import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/cleanup.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/color_space.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/downscale.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_detector.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_features.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_mesh.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/outline.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/palette_mapper.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/palettes.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/person_mask.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/smoothing.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/tone.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

export 'package:neo_brutalism_locket/features/image_engine/pixel_art/palettes.dart';

const _upscale = 4;

/// Width of the pixel grid. A slower device automatically falls back to
/// [_fallbackGridWidth] when one pass takes more than five seconds.
const pixelGridWidth = 128;
const _fallbackGridWidth = 96;

/// The single 8-bit engine: fully on-device, offline and deterministic.
class Pixel8BitStyleEngine implements StyleEngine {
  const Pixel8BitStyleEngine();

  @override
  Future<StyleOutput> process(
    File originalFile,
    StyleType styleType, {
    StyleProgress? onProgress,
  }) async {
    if (styleType != StyleType.pixel8bit) {
      throw ArgumentError.value(styleType, 'styleType');
    }
    final originalBytes = await originalFile.readAsBytes();
    final faceModel = await _loadAsset('blaze_face_short_range.tflite');
    final meshModel = await _loadAsset('face_landmark.tflite');
    final segModel = await _loadAsset('selfie_segmentation.tflite');
    final stopwatch = Stopwatch()..start();
    var pngBytes = await compute(pixel8BitFilterInBackground, {
      'bytes': originalBytes,
      'pixelWidth': pixelGridWidth,
      'faceModel': faceModel,
      'meshModel': meshModel,
      'segModel': segModel,
    });
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      pngBytes = await compute(pixel8BitFilterInBackground, {
        'bytes': originalBytes,
        'pixelWidth': _fallbackGridWidth,
        'faceModel': faceModel,
        'meshModel': meshModel,
        'segModel': segModel,
      });
    }
    final file = await writeProcessedPng(
      originalFile,
      styleType.name,
      pngBytes,
    );
    return StyleOutput(file, StyleSource.onDevice);
  }
}

Future<Uint8List?> _loadAsset(String name) async {
  try {
    final data = await rootBundle.load('assets/models/$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    return null;
  }
}

/// Deterministic pixel-art pipeline:
/// tone mapping -> Kuwahara smoothing -> k-centroid downscale -> palette
/// mapping -> outline -> orphan cleanup -> nearest-neighbour upscale.
Uint8List pixel8BitFilterInBackground(Map<String, Object?> request) {
  final bytes = request['bytes'];
  final pixelWidth = request['pixelWidth'];
  final allowPreview = request['allowPreview'] == true;
  if (bytes is! Uint8List || pixelWidth is! int) {
    throw const FormatException('8-bit filter input is incomplete.');
  }
  if (pixelWidth < (allowPreview ? 16 : 96) || pixelWidth > 192) {
    throw RangeError.range(
      pixelWidth,
      allowPreview ? 16 : 96,
      192,
      'pixelWidth',
    );
  }

  final palette = PaletteInfo(
    (request['palette'] as List<int>?) ?? endesga32Palette,
  );

  final source = decodeOrientedImage(bytes);
  // The frame is never zoomed onto a face: the picture keeps the composition
  // the user shot (centred square). Faces only steer the face-detail passes.
  var faces = <FaceBox>[
    for (final f in (request['faceBoxes'] as List?) ?? const [])
      FaceBox(f[0], f[1], f[2], f[3], f.length > 4 ? f[4] : 1),
  ];
  final faceModel = request['faceModel'];
  if (faces.isEmpty && faceModel is Uint8List) {
    faces = detectFaces(faceModel, source);
  }
  faces = subjectFaces(faces, source.width, source.height);
  final crop = subjectCrop(source.width, source.height, const []);
  final square = img.copyCrop(
    source,
    x: crop.x,
    y: crop.y,
    width: crop.side,
    height: crop.side,
  );
  final workingSize = pixelWidth * _upscale;
  final working = img.copyResize(
    square,
    width: workingSize,
    height: workingSize,
    interpolation: img.Interpolation.average,
  );

  final rgb = Float32List(workingSize * workingSize * 3);
  for (var y = 0; y < workingSize; y++) {
    for (var x = 0; x < workingSize; x++) {
      final pixel = working.getPixel(x, y);
      final o = (y * workingSize + x) * 3;
      rgb[o] = pixel.r.toDouble();
      rgb[o + 1] = pixel.g.toDouble();
      rgb[o + 2] = pixel.b.toDouble();
    }
  }

  autoLevels(rgb);
  autoGamma(rgb);
  clarity(rgb, workingSize, workingSize);
  final smooth = kuwahara(rgb, workingSize, workingSize);

  final workingLab = Float32List(workingSize * workingSize * 3);
  for (var i = 0; i < workingSize * workingSize; i++) {
    final o = i * 3;
    srgbToOklab(smooth[o], smooth[o + 1], smooth[o + 2], workingLab, o);
  }
  // Face landmarks (eyes, brows, mouth, outline) and the person/background
  // split. Either may be missing: the pipeline then falls back to the face
  // ellipse and a uniform background treatment.
  final meshes = <FaceMesh?>[
    for (var i = 0; i < faces.length; i++)
      _faceMesh(request, source, faces[i], i),
  ];
  final found = meshes.whereType<FaceMesh>().toList();
  final mask = _faceMaskFor(faces, meshes, crop, pixelWidth);
  final personRaw = _personRaw(request, source, crop);
  final person = personRaw == null ? null : _personGrid(personRaw, pixelWidth);

  final blend = Float32List(pixelWidth * pixelWidth);
  for (var i = 0; i < blend.length; i++) {
    blend[i] = person == null
        ? _backgroundBlend
        : (person[i] >= 0.5 ? _subjectBlend : _flatBackgroundBlend);
  }
  final lab = kCentroidDownscale(
    workingLab,
    workingSize,
    workingSize,
    _upscale,
    keepDark: mask,
    blendMap: blend,
  );
  _faceContrast(lab, mask, pixelWidth);
  _liftShadows(lab, pixelWidth);
  paintFaceFeatures(lab, pixelWidth, found, crop);

  for (var i = 0; i < pixelWidth * pixelWidth; i++) {
    lab[i * 3 + 1] *= 1.15;
    lab[i * 3 + 2] *= 1.15;
  }

  final edges = sobelMagnitude(lab, pixelWidth, pixelWidth);
  final palettes = _regionPalettes(
    lab,
    edges,
    mask,
    person,
    pixelWidth,
    palette,
  );
  final active = palettes.active;
  final indices = palettes.map(lab, edges, pixelWidth, mask, person);
  applyOutline(indices, lab, edges, pixelWidth, pixelWidth, active);
  removeOrphans(indices, pixelWidth, pixelWidth);
  removeSpeckles(indices, pixelWidth, pixelWidth, keep: mask);

  final outputSize = pixelWidth * _upscale;
  final output = img.Image(
    width: outputSize,
    height: outputSize,
    numChannels: 3,
  );
  for (var y = 0; y < outputSize; y++) {
    for (var x = 0; x < outputSize; x++) {
      final color =
          active.colors[indices[(y ~/ _upscale) * pixelWidth + x ~/ _upscale]];
      output.setPixelRgb(x, y, color >> 16, (color >> 8) & 0xFF, color & 0xFF);
    }
  }
  return Uint8List.fromList(img.encodePng(output, level: 3));
}

/// Stretches lightness around the face's mean so features separate from skin.
void _faceContrast(Float32List lab, Uint8List mask, int size) {
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < size * size; i++) {
    if (mask[i] != 0) {
      sum += lab[i * 3];
      count++;
    }
  }
  if (count == 0) return;
  final mean = sum / count;
  for (var i = 0; i < size * size; i++) {
    if (mask[i] != 0) lab[i * 3] = mean + (lab[i * 3] - mean) * 1.25;
  }
}

/// Lifts deep shadows so they land on the palette's dark-but-not-black colours
/// instead of one flat black mass.
void _liftShadows(Float32List lab, int size) {
  for (var i = 0; i < size * size; i++) {
    final l = lab[i * 3];
    if (l < 0.45) lab[i * 3] = l + 0.07 * (1 - l / 0.45);
  }
}

/// Share of the block average mixed into non-face areas, per region. With no
/// person found everything outside the face gets [_backgroundBlend]; with one,
/// the body is kept crisper and the background is flattened.
const _backgroundBlend = 0.5;
const _subjectBlend = 0.3;
const _flatBackgroundBlend = 0.8;

/// How many of the palette's colours one picture may use. Fewer colours make
/// a calmer, more deliberate picture; the face counts eightfold so skin tones
/// always make the cut. With a person found, the subject and the background
/// get their own, smaller budgets.
const _colorsPerImage = 18;
const _subjectColors = 14;
const _backgroundColors = 6;

/// Faces that count as the subject: not tiny (a phone screen, a poster), not a
/// weak detection (food, textures), at most four.
List<FaceBox> subjectFaces(List<FaceBox> boxes, int width, int height) {
  final minSide = math.min(width, height) * 0.07;
  return boxes
      .where((f) => f.width >= minSide && f.score >= 0.6)
      .take(4)
      .toList();
}

/// The mesh for [face]: from precomputed raw outputs in the request (tests,
/// offline renders) or from the model. A tilted face is looked at a second time
/// with the crop levelled on its eyes.
FaceMesh? _faceMesh(
  Map<String, Object?> request,
  img.Image source,
  FaceBox face,
  int index,
) {
  FaceMeshRaw? infer(String injectedKey, FaceMeshCrop crop) {
    final injected = request[injectedKey];
    if (injected is List) {
      if (index < injected.length && injected[index] != null) {
        final item = injected[index] as List;
        return FaceMeshRaw(item[0] as Float32List, (item[1] as num).toDouble());
      }
      return null;
    }
    final model = request['meshModel'];
    return model is Uint8List
        ? runFaceMeshModel(model, faceMeshInput(source, crop))
        : null;
  }

  final crop = faceMeshCrop(face);
  final raw = infer('meshRaw', crop);
  final first = raw == null
      ? null
      : decodeFaceMesh(raw.landmarks, raw.faceLogit, crop);
  if (first == null) return null;
  final refined = refinedMeshCrop(crop, first);
  if (refined == null) return first;
  final second = infer('meshRaw2', refined);
  final mesh = second == null
      ? null
      : decodeFaceMesh(second.landmarks, second.faceLogit, refined);
  return mesh ?? first;
}

/// Face mask: the mesh outline where there is a mesh, the ellipse otherwise.
Uint8List _faceMaskFor(
  List<FaceBox> faces,
  List<FaceMesh?> meshes,
  SubjectCrop crop,
  int grid,
) {
  final mask = meshFaceMask(meshes.whereType<FaceMesh>().toList(), crop, grid);
  final plain = [
    for (var i = 0; i < faces.length; i++)
      if (meshes[i] == null) faces[i],
  ];
  if (plain.isNotEmpty) {
    final ellipses = faceMask(plain, crop, grid);
    for (var i = 0; i < mask.length; i++) {
      if (ellipses[i] != 0) mask[i] = 1;
    }
  }
  return mask;
}

/// Raw 256x256 person probability of the centred square, or null.
Float32List? _personRaw(
  Map<String, Object?> request,
  img.Image source,
  SubjectCrop crop,
) {
  final injected = request['segRaw'];
  if (injected is Float32List) return injected;
  final model = request['segModel'];
  if (model is! Uint8List) return null;
  return runSegmentationModel(
    model,
    segmentationInput(source, crop.x, crop.y, crop.side),
  );
}

/// Person probability on the pixel grid, or null when nobody was found.
Float32List? _personGrid(Float32List raw, int grid) {
  final mask = personMaskToGrid(raw, grid);
  return hasPerson(mask) ? mask : null;
}

/// The colours a picture uses: one set for the subject and one, smaller, for
/// the background (or a single set when no person was found).
class _RegionPalettes {
  _RegionPalettes(this.active, this._subject, this._background);

  final PaletteInfo active;
  final PaletteInfo _subject;
  final PaletteInfo? _background;

  Uint8List map(
    Float32List lab,
    Float32List edges,
    int size,
    Uint8List face,
    Float32List? person,
  ) {
    final lookup = {
      for (var i = 0; i < active.colors.length; i++) active.colors[i]: i,
    };
    Uint8List run(PaletteInfo palette) {
      final raw = mapToColorPalette(
        lab,
        edges,
        size,
        size,
        palette,
        noDither: face,
        spread: 0.04,
      );
      return Uint8List.fromList([
        for (final i in raw) lookup[palette.colors[i]]!,
      ]);
    }

    final subject = run(_subject);
    final background = _background;
    if (background == null || person == null) return subject;
    final other = run(background);
    for (var i = 0; i < subject.length; i++) {
      if (person[i] < 0.5 && face[i] == 0) subject[i] = other[i];
    }
    return subject;
  }
}

_RegionPalettes _regionPalettes(
  Float32List lab,
  Float32List edges,
  Uint8List face,
  Float32List? person,
  int size,
  PaletteInfo full,
) {
  final first = mapToColorPalette(
    lab,
    edges,
    size,
    size,
    full,
    noDither: face,
    spread: 0,
  );
  List<int> top(bool Function(int pixel) inRegion, int count) {
    final weight = List<int>.filled(full.colors.length, 0);
    for (var i = 0; i < first.length; i++) {
      if (inRegion(i)) weight[first[i]] += face[i] != 0 ? 8 : 1;
    }
    final order = List<int>.generate(full.colors.length, (i) => i)
      ..sort((a, b) => weight[b].compareTo(weight[a]));
    return order.take(count).where((i) => weight[i] > 0).toList()..sort();
  }

  PaletteInfo palette(Iterable<int> ids) =>
      PaletteInfo([for (final i in ids) full.colors[i]]);

  if (person == null) {
    final all = palette(top((_) => true, _colorsPerImage));
    return _RegionPalettes(all, all, null);
  }
  final subject = top((i) => person[i] >= 0.5 || face[i] != 0, _subjectColors);
  final background = top(
    (i) => person[i] < 0.5 && face[i] == 0,
    _backgroundColors,
  );
  final union = {...subject, ...background}.toList()..sort();
  return _RegionPalettes(palette(union), palette(subject), palette(background));
}
