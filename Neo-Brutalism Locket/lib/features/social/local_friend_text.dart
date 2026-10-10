import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

String localFriendText(AppLocalizations l10n, LocalFriendException error) =>
    switch (error.kind) {
      LocalFriendError.needNameHandle => l10n.lfNeedNameHandle,
      LocalFriendError.handleTaken => l10n.lfHandleTaken,
      LocalFriendError.writeSomething => l10n.lfWriteSomething,
      LocalFriendError.friendMissing => l10n.lfFriendMissing,
      LocalFriendError.writeReply => l10n.lfWriteReply,
      LocalFriendError.postGone => l10n.lfPostGone,
    };
