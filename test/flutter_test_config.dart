import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

import 'helpers/localization.dart';

/// Runs before every test file: the app's English texts are loaded so
/// widgets and messages render as users see them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  loadTestTranslations();
  await testMain();
}
