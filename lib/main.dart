import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/di/injection.dart';
import 'core/services/id_generator.dart';
import 'core/services/local_media_store.dart';
import 'core/services/local_notification_service.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/storage_bootstrap.dart';
import 'core/widgets/state_views.dart';
import 'features/daily_goals/domain/usecases/daily_goal_use_cases.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // Goal reminders skip goals already reached today; refresh them on
    // every launch. Failures are reported inside and never block startup.
    unawaited(getIt<SyncGoalRemindersUseCase>()());
    runApp(GainItApp(router: createRouter()));
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    runApp(const _StartupFailureApp());
  }
}

/// Shown only if local storage cannot be opened at all.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(
        body: ErrorView(
          message:
              'GainIt could not open its local data. Please restart the app.',
        ),
      ),
    );
  }
}
