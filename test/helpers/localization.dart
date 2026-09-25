import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// The public API only loads translations through the EasyLocalization
// widget; tests of single widgets and units load them directly.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/l10n/app_locales.dart';

Map<String, dynamic> readTranslations(String languageCode) =>
    jsonDecode(
          File('assets/translations/$languageCode.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Makes `tr()` return the app's texts in [languageCode] (English by
/// default; set for every test in `flutter_test_config.dart`).
void loadTestTranslations([String languageCode = 'en']) {
  Intl.defaultLocale = languageCode;
  Localization.load(
    Locale(languageCode),
    translations: Translations(readTranslations(languageCode)),
    fallbackTranslations: Translations(readTranslations('en')),
    ignorePluralRules: false,
  );
}

/// Reads the translation files straight from disk. The bundle loader
/// completes outside the test's fake clock, so later tests would never see
/// their texts load.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      readTranslations(locale.languageCode);
}

/// Wraps the real app the way `main` does, for full-app tests.
Widget localizedApp(Widget app, {Locale locale = AppLocales.english}) =>
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: AppLocales.path,
      fallbackLocale: AppLocales.fallback,
      startLocale: locale,
      saveLocale: false,
      useOnlyLangCode: true,
      ignorePluralRules: false,
      assetLoader: const _FileAssetLoader(),
      child: app,
    );

/// Pumps [app] inside [localizedApp] and waits until its texts are loaded.
Future<void> pumpLocalizedApp(
  WidgetTester tester,
  Widget app, {
  Locale locale = AppLocales.english,
}) async {
  await tester.pumpWidget(localizedApp(app, locale: locale));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}
