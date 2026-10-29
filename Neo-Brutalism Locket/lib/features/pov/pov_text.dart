import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What to tell the person when something went wrong with a code.
String povFailureText(AppLocalizations l10n, PovFailure failure) =>
    switch (failure.kind) {
      PovFailureKind.busy => l10n.povErrBusy,
      PovFailureKind.notFriends => l10n.povErrNotFriends,
      PovFailureKind.expired => l10n.povErrExpired,
      PovFailureKind.notFound => l10n.povErrNotFound,
      PovFailureKind.self => l10n.povErrSelf,
      PovFailureKind.tooMany => l10n.povErrTooMany,
      PovFailureKind.network => l10n.povErrNetwork,
      PovFailureKind.unknown => l10n.povErrUnknown,
    };

/// Why a session ended, in a sentence ([name] is the other person).
String povEndText(AppLocalizations l10n, PovEnd end, String name) =>
    switch (end) {
      PovEnd.expired => l10n.povQrExpired,
      PovEnd.ended => l10n.povEndEnded(name),
      PovEnd.lostConnection => l10n.povEndLost,
    };

/// "m:ss", for the time a code has left.
String povClock(Duration left) {
  final seconds = left.isNegative ? 0 : left.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
