import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/ort_image_encoder.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_preprocess.dart';

/// Model input size of the image encoder (server/eval/export_quest_model.py).
const searchImageSize = 256;

/// Values per vector, and bytes as stored on a post (float16).
const embeddingDimension = 512;
const embeddingBytes = embeddingDimension * 2;

Float32List _planes(Uint8List photo) =>
    preprocessQuestPhoto(photo, searchImageSize);

/// What a photo shows, as the vector stored on its post
/// (`posts.embedding`, see supabase/migrations/20261022000001_post_embeddings.sql):
/// the quest's image encoder, float16, base64. Null when the photo cannot be
/// read or the model fails: a post is never held back for its vector.
Future<String?> embedPhotoForSearch(
  Uint8List photo, {
  QuestImageEncoder? encoder,
}) async {
  try {
    final planes = await compute(_planes, photo);
    final vector = await (encoder ?? OrtQuestImageEncoder.shared).encode(
      planes,
      searchImageSize,
    );
    if (vector.length != embeddingDimension) return null;
    return base64Encode(float16Bytes(vector));
  } catch (e, st) {
    AppLog.warn('photo_embedding', e, st);
    return null;
  }
}

/// [values] as little-endian IEEE float16 (round to nearest even).
Uint8List float16Bytes(Float32List values) {
  final out = ByteData(values.length * 2);
  final bits = ByteData(4);
  for (var i = 0; i < values.length; i++) {
    bits.setFloat32(0, values[i]);
    out.setUint16(i * 2, _toHalf(bits.getUint32(0)), Endian.little);
  }
  return out.buffer.asUint8List();
}

/// The inverse of [float16Bytes].
Float32List float32FromFloat16Bytes(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final out = Float32List(bytes.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = _fromHalf(data.getUint16(i * 2, Endian.little));
  }
  return out;
}

int _toHalf(int f) {
  final sign = (f >> 16) & 0x8000;
  final exponent = ((f >> 23) & 0xff) - 127 + 15;
  var mantissa = f & 0x7fffff;
  if (((f >> 23) & 0xff) == 0xff) {
    return sign | 0x7c00 | (mantissa != 0 ? 0x200 : 0); // inf / nan
  }
  if (exponent >= 0x1f) return sign | 0x7c00; // too big: inf
  if (exponent <= 0) {
    if (exponent < -10) return sign; // too small: zero
    mantissa |= 0x800000; // subnormal half
    final shift = 14 - exponent;
    var half = mantissa >> shift;
    final rest = mantissa & ((1 << shift) - 1);
    final halfway = 1 << (shift - 1);
    if (rest > halfway || (rest == halfway && (half & 1) == 1)) half++;
    return sign | half;
  }
  var half = (exponent << 10) | (mantissa >> 13);
  final rest = mantissa & 0x1fff;
  if (rest > 0x1000 || (rest == 0x1000 && (half & 1) == 1)) half++;
  return sign | half; // a carry into the exponent is still correct
}

double _fromHalf(int h) {
  final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
  final exponent = (h >> 10) & 0x1f;
  final mantissa = h & 0x3ff;
  if (exponent == 0) return sign * mantissa * 5.9604644775390625e-8; // 2^-24
  if (exponent == 0x1f) {
    return mantissa == 0 ? sign * double.infinity : double.nan;
  }
  return sign * (1 + mantissa / 1024) * _pow2(exponent - 15);
}

double _pow2(int e) {
  var v = 1.0;
  if (e >= 0) {
    for (var i = 0; i < e; i++) {
      v *= 2;
    }
  } else {
    for (var i = 0; i < -e; i++) {
      v /= 2;
    }
  }
  return v;
}
