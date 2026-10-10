import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What the waiting bar says while a style is being made. The engines report
/// their own stage names (some come from the laptop server), so the bar says
/// what is happening in the app's voice instead.
String styleWorkingLabel(AppLocalizations l10n, StyleType? style) =>
    switch (style) {
      StyleType.pixel8bit => l10n.styleWorking8bit,
      StyleType.vanGogh => l10n.styleWorkingVanGogh,
      _ => l10n.styleWorking,
    };
