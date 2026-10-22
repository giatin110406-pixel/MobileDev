import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:neo_brutalism_locket/features/search/clip_tokenizer.dart';

/// The search text model (MobileCLIP2-S0 text encoder, 4-bit, 38.6 MB),
/// shipped in the app like the quest's image model. Made by
/// server/eval/export_text_model.py.
const searchModelAsset = 'assets/search_model/search_text_encoder_4bit.onnx';

/// An English sentence -> a unit vector in the same space as the photo
/// vectors of the quest image encoder.
class SearchTextEncoder {
  SearchTextEncoder({
    this.asset = searchModelAsset,
    OnnxRuntime? runtime,
    Future<ClipTokenizer> Function()? loadTokenizer,
  }) : _runtime = runtime ?? OnnxRuntime(),
       _loadTokenizer = loadTokenizer ?? ClipTokenizer.load;

  final String asset;
  final OnnxRuntime _runtime;
  final Future<ClipTokenizer> Function() _loadTokenizer;
  Future<OrtSession>? _session;
  Future<ClipTokenizer>? _tokenizer;

  /// Loads the model now instead of on the first query.
  Future<void> open() async {
    await (_session ??= _runtime.createSessionFromAsset(asset)).onError((
      error,
      stack,
    ) {
      _session = null; // a failed load is retried next time
      return Future<OrtSession>.error(error!, stack);
    });
  }

  Future<Float32List> encode(String english) async {
    await open();
    final session = await _session!;
    final tokenizer = await (_tokenizer ??= _loadTokenizer());
    final input = await OrtValue.fromList(tokenizer.encode(english), [
      1,
      ClipTokenizer.contextLength,
    ]);
    final outputs = await session.run({'tokens': input});
    try {
      final embedding = outputs['embedding'];
      if (embedding == null) throw StateError('model has no embedding output');
      final values = await embedding.asFlattenedList();
      return Float32List.fromList([
        for (final v in values) (v as num).toDouble(),
      ]);
    } finally {
      await input.dispose();
      for (final value in outputs.values) {
        await value.dispose();
      }
    }
  }

  Future<void> close() async {
    final session = _session;
    _session = null;
    if (session != null) await (await session).close();
  }
}
