import 'package:neo_brutalism_locket/features/image_engine/fallback_text.dart';
import 'package:neo_brutalism_locket/features/quest/quest_verifier.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What to tell the player when their quest photo could not be checked.
String questCheckText(AppLocalizations l10n, QuestCheckUnavailable error) =>
    switch (error.kind) {
      QuestCheckError.needsLaptop => l10n.qcNeedsLaptop,
      QuestCheckError.laptopFailed => l10n.qcLaptopFailed(
        stylizeCodeText(l10n, error.detail),
      ),
      QuestCheckError.questUnknown => l10n.qcQuestUnknown,
      QuestCheckError.unreadablePhoto => l10n.qcUnreadable,
      QuestCheckError.deviceFailed => l10n.qcDeviceFailed,
    };
