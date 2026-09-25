import 'package:flutter/widgets.dart';

import '../domain/entities/app_settings.dart';

/// Languages GainIt ships in, and where their texts live.
abstract final class AppLocales {
  static const english = Locale('en');
  static const arabic = Locale('ar');

  static const supported = [english, arabic];
  static const fallback = english;
  static const path = 'assets/translations';

  /// The saved language, or `null` to follow the phone.
  static Locale? fromCode(String? code) =>
      code != null && AppSettings.supportedLanguageCodes.contains(code)
      ? Locale(code)
      : null;
}
