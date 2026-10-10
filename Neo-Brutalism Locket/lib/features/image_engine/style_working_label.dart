import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// A style's name for the screen: the proper names (VAN GOGH, 8-BIT) as they
/// are, and "no style" in the app's language.
String styleName(AppLocalizations l10n, StyleType style) =>
    style == StyleType.none ? l10n.styleNone : style.label;

/// Which path made a picture (shown on the print), in words.
String styleSourceLabel(AppLocalizations l10n, StyleSource source) =>
    switch (source) {
      StyleSource.laptopDiffusion => l10n.sourceLaptop,
      StyleSource.onDevice => l10n.sourceOnDevice,
      StyleSource.magenta => l10n.sourceMagenta,
      StyleSource.mock => l10n.sourceMock,
      StyleSource.original => l10n.sourceOriginal,
    };

/// What the waiting bar says while a style is being made. The engines report
/// their own stage names (some come from the laptop server), so the bar says
/// what is happening in the app's voice instead.
String styleWorkingLabel(AppLocalizations l10n, StyleType? style) =>
    switch (style) {
      StyleType.pixel8bit => l10n.styleWorking8bit,
      StyleType.vanGogh => l10n.styleWorkingVanGogh,
      _ => l10n.styleWorking,
    };
