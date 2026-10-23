import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/ort_image_encoder.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_preprocess.dart';

/// What kind of photo it is, as far as picking a style goes.
enum PhotoScene { portrait, group, night, sky, day }

/// Exported by server/eval/export_scene_labels.py (measured there on the
/// tagged eval photos).
const sceneLabelsAsset = 'assets/quest_model/scene_labels.json';
const sceneVectorsAsset = 'assets/quest_model/scene_labels.bin';

/// The text side of the scene guess: one unit vector per description, each
/// belonging to one [PhotoScene].
class SceneLabels {
  const SceneLabels({
    required this.scenes,
    required this.vectors,
    required this.dimension,
    required this.logitScale,
    required this.inputSize,
  });

  /// [vectors] is little-endian float32, `scenes.length * dimension` numbers.
  factory SceneLabels.parse(String json, Uint8List vectors) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final dimension = data['dim'] as int;
    final scenes = [
      for (final s in data['scenes'] as List<dynamic>)
        PhotoScene.values.byName(s as String),
    ];
    if (vectors.lengthInBytes != scenes.length * dimension * 4) {
      throw const FormatException('scene vectors do not match labels');
    }
    final bytes = ByteData.sublistView(vectors);
    final floats = Float32List(scenes.length * dimension);
    for (var i = 0; i < floats.length; i++) {
      floats[i] = bytes.getFloat32(i * 4, Endian.little);
    }
    return SceneLabels(
      scenes: scenes,
      vectors: floats,
      dimension: dimension,
      logitScale: (data['logitScale'] as num).toDouble(),
      inputSize: data['inputSize'] as int,
    );
  }

  static Future<SceneLabels> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final json = await assets.loadString(sceneLabelsAsset);
    final data = await assets.load(sceneVectorsAsset);
    return SceneLabels.parse(
      json,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// The scene of each description, in the order of [vectors].
  final List<PhotoScene> scenes;
  final Float32List vectors;
  final int dimension;
  final double logitScale;
  final int inputSize;
}

/// Same rule as `guess` in export_scene_labels.py: softmax over every
/// description, probability added up per scene, the largest wins.
PhotoScene guessScene(Float32List embedding, SceneLabels bank) {
  if (embedding.length != bank.dimension) {
    throw ArgumentError.value(embedding.length, 'embedding', 'wrong size');
  }
  final logits = List<double>.filled(bank.scenes.length, 0);
  var largest = double.negativeInfinity;
  for (var k = 0; k < logits.length; k++) {
    final base = k * bank.dimension;
    var dot = 0.0;
    for (var d = 0; d < bank.dimension; d++) {
      dot += embedding[d] * bank.vectors[base + d];
    }
    logits[k] = dot * bank.logitScale;
    largest = math.max(largest, logits[k]);
  }
  final totals = List<double>.filled(PhotoScene.values.length, 0);
  for (var k = 0; k < logits.length; k++) {
    totals[bank.scenes[k].index] += math.exp(logits[k] - largest);
  }
  var best = 0;
  for (var s = 1; s < totals.length; s++) {
    if (totals[s] > totals[best]) best = s;
  }
  return PhotoScene.values[best];
}

Float32List _planes((Uint8List, int) job) =>
    preprocessQuestPhoto(job.$1, job.$2);

/// Guesses the scene of a photo on the phone with the quest's image encoder.
/// Never throws: any failure (model missing, unreadable photo) gives null, and
/// the callers then behave as they did before scenes existed.
class SceneGuesser {
  SceneGuesser({
    QuestImageEncoder? encoder,
    Future<SceneLabels> Function()? loadLabels,
  }) : _encoder = encoder ?? OrtQuestImageEncoder.shared,
       _loadLabels = loadLabels ?? SceneLabels.load;

  static final shared = SceneGuesser();

  final QuestImageEncoder _encoder;
  final Future<SceneLabels> Function() _loadLabels;
  Future<SceneLabels>? _labels;

  // The Van Gogh server attempt and its on-phone fallback ask about the same
  // photo one after the other; it is only encoded once.
  Uint8List? _lastPhoto;
  Future<PhotoScene?>? _lastGuess;

  Future<PhotoScene?> guess(Uint8List photo) {
    final last = _lastPhoto;
    if (last != null && _lastGuess != null && _same(last, photo)) {
      return _lastGuess!;
    }
    _lastPhoto = photo;
    return _lastGuess = _run(photo);
  }

  Future<PhotoScene?> _run(Uint8List photo) async {
    try {
      final labels = await (_labels ??= _loadLabels());
      final planes = await compute(_planes, (photo, labels.inputSize));
      final embedding = await _encoder.encode(planes, labels.inputSize);
      return guessScene(embedding, labels);
    } catch (error) {
      _labels = null;
      if (kDebugMode) debugPrint('scene guess failed: $error');
      return null;
    }
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// [SceneGuesser.shared] as a plain function, so const constructors can take
/// it as a default.
Future<PhotoScene?> guessPhotoScene(Uint8List photo) =>
    SceneGuesser.shared.guess(photo);

/// The style worth offering for a scene, or null when both styles suit it.
/// Groups: Van Gogh repaints small faces into other people, 8-bit keeps them.
/// Night and sky: the lights and skies are what Van Gogh painted best.
StyleType? suggestedStyle(PhotoScene scene) => switch (scene) {
  PhotoScene.group => StyleType.pixel8bit,
  PhotoScene.night || PhotoScene.sky => StyleType.vanGogh,
  PhotoScene.portrait || PhotoScene.day => null,
};
