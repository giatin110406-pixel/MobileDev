import 'package:flutter/widgets.dart';
import 'package:neo_brutalism_locket/core/language.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The demo friends are seeded once, in English, and kept on the phone. This
/// shows their posts and messages in the app's language; any other text (what
/// you or a real friend wrote) comes back as it is.
String sampleText(BuildContext context, String text) {
  final l10n = AppLocalizations.of(context);
  final known = switch (text) {
    'Morning light looked unreal' => l10n.sampleCaptionAva,
    'Coffee walk after class' => l10n.sampleCaptionJules,
    'Fresh print from the darkroom' => l10n.sampleCaptionRemy,
    'Morning light looked unreal today.' => l10n.sampleMessageAva,
    'Coffee walk after class?' => l10n.sampleMessageJules,
    'That print turned out so good.' => l10n.sampleMessageRemy,
    _ => null,
  };
  if (known != null) return known;
  // The demo quest posts carry a quest caption: show it in the right language.
  for (final quest in questCatalog) {
    if (text == quest.caption || text == quest.captionEn) {
      return quest.captionFor(vietnamese: isVietnamese(context));
    }
  }
  return text;
}
