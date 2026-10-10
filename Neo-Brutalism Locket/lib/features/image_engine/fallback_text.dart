import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// One reason code, e.g. "laptop:wrongToken" or "laptop:status|503", in words.
String stylizeCodeText(AppLocalizations l10n, String code) {
  final cut = code.indexOf('|');
  final head = cut < 0 ? code : code.substring(0, cut);
  final detail = cut < 0 ? '' : code.substring(cut + 1);
  return switch (head) {
    'laptop:notSetUp' => l10n.seNotSetUp,
    'laptop:tooLong' => l10n.seTooLong,
    'laptop:wrongToken' => l10n.seWrongToken,
    'laptop:tooLarge' => l10n.sePhotoTooLarge,
    'laptop:busy' => l10n.seBusy,
    'laptop:noAnswer' => l10n.seNoAnswer,
    'laptop:unreachable' => l10n.seUnreachable,
    'laptop:failed' =>
      detail.isEmpty ? l10n.seFailed : l10n.seFailedDetail(detail),
    'laptop:status' => l10n.seStatus(detail),
    'magenta:failed' => l10n.seMagentaFailed,
    _ => l10n.seError,
  };
}

/// Why a fallback picture was made: the reason codes joined by "; ", in words.
String fallbackNoteText(AppLocalizations l10n, String note) =>
    note.split('; ').map((code) => stylizeCodeText(l10n, code)).join('; ');
