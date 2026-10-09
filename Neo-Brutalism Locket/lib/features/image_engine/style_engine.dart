import 'dart:io';

import 'style_result.dart';
import 'style_type.dart';

abstract interface class StyleEngine {
  Future<StyleOutput> process(
    File originalFile,
    StyleType styleType, {
    StyleProgress? onProgress,
  });
}
