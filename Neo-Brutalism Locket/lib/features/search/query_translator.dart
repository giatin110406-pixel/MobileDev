import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Vietnamese -> English on the phone (Google ML Kit), because the search
/// model only understands English. The language pack (~30 MB) is downloaded
/// once; after that it works offline and the text never leaves the phone.
class QueryTranslator {
  QueryTranslator({OnDeviceTranslatorModelManager? models})
    : _models = models ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _models;
  OnDeviceTranslator? _translator;

  Future<bool> get isReady =>
      _models.isModelDownloaded(TranslateLanguage.vietnamese.bcpCode);

  /// Downloads the Vietnamese pack if it is missing. [wifiOnly] waits for
  /// Wi-Fi instead of using mobile data.
  Future<bool> prepare({bool wifiOnly = true}) async {
    if (await isReady) return true;
    return _models.downloadModel(
      TranslateLanguage.vietnamese.bcpCode,
      isWifiRequired: wifiOnly,
    );
  }

  Future<String> toEnglish(String vietnamese) =>
      (_translator ??= OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.vietnamese,
        targetLanguage: TranslateLanguage.english,
      )).translateText(vietnamese);

  Future<void> close() async {
    await _translator?.close();
    _translator = null;
  }
}
