import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';

const _channel = MethodChannel(
  'com.neobrutalism.neo_brutalism_locket/square_crop',
);

/// The camera shot at [path] as a centred 1:1 JPEG, like the viewfinder.
/// On Android the phone's own decoder does it (only the square is decoded);
/// elsewhere, or if that fails, [cropToSquareJpeg] does it in an isolate.
Future<Uint8List> cropShotToSquare(String path) async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('cropToSquareJpeg', {
        'path': path,
        'quality': 92,
      });
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (e, st) {
      AppLog.warn('square_crop', e, st);
    }
  }
  return compute(cropToSquareJpeg, await File(path).readAsBytes());
}
