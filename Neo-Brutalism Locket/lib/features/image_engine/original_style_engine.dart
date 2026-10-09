import 'dart:io';

import 'package:neo_brutalism_locket/features/image_engine/style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

/// "No style": the print is the original photo, untouched and instant.
class OriginalStyleEngine implements StyleEngine {
  const OriginalStyleEngine();

  @override
  Future<StyleOutput> process(
    File originalFile,
    StyleType styleType, {
    StyleProgress? onProgress,
  }) async {
    if (styleType != StyleType.none) {
      throw ArgumentError.value(styleType, 'styleType');
    }
    return StyleOutput(originalFile, StyleSource.original);
  }
}
