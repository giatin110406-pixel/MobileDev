import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Where the exported model lives (see server/eval/export_quest_model.py).
const questModelAsset = 'assets/quest_model/quest_image_encoder_fp16.onnx';
const questLabelsAsset = 'assets/quest_model/quest_labels.json';
const questVectorsAsset = 'assets/quest_model/quest_labels.bin';

/// One quest's labels: the first [positives] of [labelIds] are the accepted
/// descriptions, the rest are everything it must beat.
class QuestLabelSet {
  const QuestLabelSet({required this.positives, required this.labelIds});

  final int positives;
  final List<int> labelIds;
}

/// The text side of the photo check: one unit vector per label, computed
/// ahead of time, so the phone only has to run the image encoder.
class QuestLabels {
  QuestLabels({
    required this.labels,
    required this.vectors,
    required this.dimension,
    required this.logitScale,
    required this.matchScore,
    required this.inputSize,
    required this.quests,
  });

  /// Reads the two exported files. [vectors] is little-endian float32,
  /// `labels.length * dimension` numbers.
  factory QuestLabels.parse(String json, Uint8List vectors) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final dimension = data['dim'] as int;
    final labels = [for (final l in data['labels'] as List<dynamic>) '$l'];
    if (vectors.lengthInBytes != labels.length * dimension * 4) {
      throw const FormatException('quest label vectors do not match labels');
    }
    final bytes = ByteData.sublistView(vectors);
    final floats = Float32List(labels.length * dimension);
    for (var i = 0; i < floats.length; i++) {
      floats[i] = bytes.getFloat32(i * 4, Endian.little);
    }
    return QuestLabels(
      labels: labels,
      vectors: floats,
      dimension: dimension,
      logitScale: (data['logitScale'] as num).toDouble(),
      matchScore: (data['matchScore'] as num).toDouble(),
      inputSize: data['inputSize'] as int,
      quests: {
        for (final entry in (data['quests'] as Map<String, dynamic>).entries)
          entry.key: QuestLabelSet(
            positives:
                (entry.value as Map<String, dynamic>)['positives'] as int,
            labelIds: [
              for (final id
                  in (entry.value as Map<String, dynamic>)['labels']
                      as List<dynamic>)
                id as int,
            ],
          ),
      },
    );
  }

  static Future<QuestLabels> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final json = await assets.loadString(questLabelsAsset);
    final data = await assets.load(questVectorsAsset);
    return QuestLabels.parse(
      json,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  final List<String> labels;
  final Float32List vectors;
  final int dimension;
  final double logitScale;
  final double matchScore;
  final int inputSize;
  final Map<String, QuestLabelSet> quests;
}

/// The verdict for one photo. [score] is the summed probability of the
/// quest's accepted descriptions, [top] the single most likely label.
class QuestScore {
  const QuestScore({
    required this.match,
    required this.score,
    required this.top,
  });

  final bool match;
  final double score;
  final String top;
}

/// Same rule as the laptop's `locket_server.verify.decide`: the photo matches
/// when an accepted description is the top label, or when they share at least
/// [QuestLabels.matchScore] of the probability between them.
QuestScore scoreQuestPhoto(
  Float32List embedding,
  QuestLabels bank,
  String questId,
) {
  final set = bank.quests[questId];
  if (set == null) {
    throw ArgumentError.value(questId, 'questId', 'not in the exported model');
  }
  if (embedding.length != bank.dimension) {
    throw ArgumentError.value(embedding.length, 'embedding', 'wrong size');
  }
  final logits = List<double>.filled(set.labelIds.length, 0);
  var largest = double.negativeInfinity;
  for (var k = 0; k < set.labelIds.length; k++) {
    final base = set.labelIds[k] * bank.dimension;
    var dot = 0.0;
    for (var d = 0; d < bank.dimension; d++) {
      dot += embedding[d] * bank.vectors[base + d];
    }
    logits[k] = dot * bank.logitScale;
    largest = math.max(largest, logits[k]);
  }
  var total = 0.0;
  for (var k = 0; k < logits.length; k++) {
    logits[k] = math.exp(logits[k] - largest);
    total += logits[k];
  }
  var top = 0;
  var accepted = 0.0;
  for (var k = 0; k < logits.length; k++) {
    final probability = logits[k] / total;
    logits[k] = probability;
    if (probability > logits[top]) top = k;
    if (k < set.positives) accepted += probability;
  }
  return QuestScore(
    match: top < set.positives || accepted >= bank.matchScore,
    score: accepted,
    top: bank.labels[set.labelIds[top]],
  );
}
