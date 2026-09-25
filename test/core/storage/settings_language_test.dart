import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/app_settings.dart';
import 'package:gainit/core/domain/validation/validators.dart';
import 'package:gainit/core/storage/local_data_sources/settings_local_data_source.dart';
import 'package:gainit/core/storage/settings_keys.dart';

import '../../helpers/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late SettingsLocalDataSource settings;

  setUp(() async {
    await harness.setUp();
    settings = SettingsLocalDataSource(harness.storage);
  });
  tearDown(harness.tearDown);

  test('the phone language is the default', () {
    expect(settings.settings().languageCode, isNull);
  });

  test('a chosen language is kept', () async {
    await settings.save(const AppSettings(languageCode: 'ar'));

    expect(settings.settings().languageCode, 'ar');
  });

  test('going back to the phone language forgets the choice', () async {
    await settings.save(const AppSettings(languageCode: 'ar'));

    await settings.save(settings.settings().copyWith(useSystemLanguage: true));

    expect(settings.settings().languageCode, isNull);
    expect(
      harness.storage.settings.containsKey(SettingsKeys.languageCode),
      isFalse,
    );
  });

  test('an unknown stored language is ignored', () async {
    await harness.storage.settings.put(SettingsKeys.languageCode, 'xx');

    expect(settings.settings().languageCode, isNull);
  });

  test('only supported languages can be saved', () {
    expect(Validators.settings(const AppSettings(languageCode: 'fr')), [
      'validation.languageUnavailable',
    ]);
  });
}
