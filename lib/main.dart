import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/di/injection.dart';
import 'core/services/local_notification_service.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/storage_bootstrap.dart';
import 'core/widgets/state_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter('gainit');
    final storage = await HiveStorage.open();
    await StorageBootstrap.run(storage, now: DateTime.now());

    final notifications = LocalNotificationService();
    // Notifications are optional; never block startup on them.
    unawaited(notifications.init().catchError((Object _) {}));

    configureDependencies(storage: storage, notifications: notifications);
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
