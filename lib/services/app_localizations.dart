import 'package:flutter/widgets.dart';

import 'app_language_service.dart';

/// Shared helper for accessing the app's existing translation service.
///
/// Widgets must listen to AppLanguageService (for example, with
/// AnimatedBuilder) to rebuild when the selected language changes.
class AppLocalizations {
  AppLocalizations._(this._service);

  final AppLanguageService _service;

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations._(AppLanguageService.instance);
  }

  /// Returns the translation for [key].
  ///
  /// If the key is missing, [fallback] is returned when supplied.
  String tr(String key, {String? fallback}) {
    final translated = _service.translate(key);

    if (translated == key && fallback != null) {
      return fallback;
    }

    return translated;
  }

  String get languageCode => _service.languageCode;

  AppLanguage get language => _service.language;

  bool get isLoaded => _service.isLoaded;

  bool get isSaving => _service.isSaving;
}
