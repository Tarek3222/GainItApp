import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/di/injection.dart';
import 'core/l10n/app_locales.dart';
import 'core/services/id_generator.dart';
import 'core/services/local_media_store.dart';
import 'core/services/local_notification_service.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/local_data_sources/settings_local_data_source.dart';
import 'core/storage/storage_bootstrap.dart';
import 'core/widgets/state_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  // Date names for every language, so dates format correctly anywhere.
  await initializeDateFormatting();

  try {
    await Hive.initFlutter('gainit');
    final storage = await HiveStorage.open();
    await StorageBootstrap.run(storage, now: DateTime.now());

    final notifications = LocalNotificationService();
    // Notifications are optional; never block startup on them.
    unawaited(notifications.init().catchError((Object _) {}));

    // Resolved on every launch: on iOS the documents path changes after an
    // app update, so only file names are stored.
    final documents = await getApplicationDocumentsDirectory();
    final temporary = await getTemporaryDirectory();
    final media = LocalMediaStore(
      const IdGenerator(),
      directory: '${documents.path}/media',
      pickerCacheDirectory: temporary.path,
    );

    configureDependencies(
      storage: storage,
      notifications: notifications,
      media: media,
    );
    final language = SettingsLocalDataSource(storage).settings().languageCode;
    runApp(
      _localized(
        startLocale: AppLocales.fromCode(language),
        child: GainItApp(router: createRouter()),
      ),
    );
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    runApp(_localized(child: const _StartupFailureApp()));
  }
}

/// The language is kept in GainIt's own settings (so it follows the rest
/// of the user's data), not in easy_localization's storage.
Widget _localized({required Widget child, Locale? startLocale}) =>
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: AppLocales.path,
      fallbackLocale: AppLocales.fallback,
      startLocale: startLocale,
      saveLocale: false,
      useOnlyLangCode: true,
      // Arabic has six plural forms.
      ignorePluralRules: false,
      child: child,
    );

/// Shown only if local storage cannot be opened at all.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: Scaffold(body: ErrorView(message: 'startup.storageFailed'.tr())),
    );
  }
}
