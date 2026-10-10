import 'package:flutter/widgets.dart';

/// True when the app is showing Vietnamese (everything but English).
///
/// For the few texts that come as a pair from data (quest stories, contest
/// themes) instead of from the language files.
bool isVietnamese(BuildContext context) =>
    Localizations.localeOf(context).languageCode != 'en';
