import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What to tell the player when a quest or shop action was refused.
String playerErrorText(AppLocalizations l10n, PlayerException error) =>
    switch (error.kind) {
      PlayerError.questExpired => l10n.peQuestExpired,
      PlayerError.alreadyDone => l10n.peAlreadyDone,
      PlayerError.noAttempts => l10n.peNoAttempts,
      PlayerError.notPassed => l10n.peNotPassed,
      PlayerError.captionTooLong => l10n.peCaptionTooLong(error.value),
      PlayerError.alreadyOwned => l10n.peAlreadyOwned,
      PlayerError.notOwned => l10n.peNotOwned,
      PlayerError.itemNotFound => l10n.peItemNotFound,
      PlayerError.needsNetwork => l10n.peNeedsNetwork,
      PlayerError.notEnoughSunbit => l10n.peNotEnoughSunbit(error.value),
      PlayerError.unknown => l10n.peUnknown,
    };
