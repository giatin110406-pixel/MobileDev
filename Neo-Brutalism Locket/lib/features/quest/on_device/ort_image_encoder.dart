import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_scoring.dart';

/// Turns a preprocessed photo into its embedding (a unit vector).
abstract interface class QuestImageEncoder {
  Future<Float32List> encode(Float32List planes, int size);
}

/// Runs the exported MobileCLIP2-S0 image encoder with ONNX Runtime. The model
/// loads on the first photo and stays loaded.
class OrtQuestImageEncoder implements QuestImageEncoder {
  OrtQuestImageEncoder({OnnxRuntime? runtime})
    : _runtime = runtime ?? OnnxRuntime();

  final OnnxRuntime _runtime;
  Future<OrtSession>? _session;

  Future<OrtSession> _open() {
    final opening = _session ??= _runtime.createSessionFromAsset(
      questModelAsset,
    );
    // A failed load must not stay cached: the next photo tries again.
    return opening.onError((error, stack) {
      _session = null;
      return Future<OrtSession>.error(error!, stack);
    });
  }

  @override
  Future<Float32List> encode(Float32List planes, int size) async {
    final session = await _open();
    final input = await OrtValue.fromList(planes, [1, 3, size, size]);
    final outputs = await session.run({'image': input});
    try {
      final embedding = outputs['embedding'];
      if (embedding == null) throw StateError('model has no embedding output');
      final values = await embedding.asFlattenedList();
      return Float32List.fromList([for (final v in values) (v as num).toDouble()]);
    } finally {
      await input.dispose();
      for (final value in outputs.values) {
        await value.dispose();
      }
    }
  }
}
