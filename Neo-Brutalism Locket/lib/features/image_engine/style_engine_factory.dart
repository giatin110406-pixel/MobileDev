import 'package:neo_brutalism_locket/features/image_engine/original_style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_8bit_style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/remote_van_gogh_backend.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/image_engine/van_gogh_style_engine.dart';

class StyleEngineFactory {
  const StyleEngineFactory();

  StyleEngine create(StyleType styleType, {VanGoghBackend? vanGoghBackend}) =>
      switch (styleType) {
        StyleType.none => const OriginalStyleEngine(),
        StyleType.pixel8bit => const Pixel8BitStyleEngine(),
        StyleType.vanGogh => VanGoghStyleEngine(
          vanGoghBackend ?? RemoteVanGoghBackend(),
        ),
      };
}
