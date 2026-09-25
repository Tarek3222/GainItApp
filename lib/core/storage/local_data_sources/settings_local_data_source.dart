import '../../domain/entities/app_settings.dart';
import '../../domain/validation/validators.dart';
import '../hive_storage.dart';
import '../settings_keys.dart';
import '../storage_guard.dart';

class SettingsLocalDataSource {
  const SettingsLocalDataSource(this._storage);

  final HiveStorage _storage;

  static const _defaults = AppSettings();

  AppSettings settings() {
    final box = _storage.settings;
    bool flag(String key, bool fallback) {
      final value = box.get(key);
      return value is bool ? value : fallback;
    }

    final minutes = box.get(SettingsKeys.reminderMinutesOfDay);
    final language = box.get(SettingsKeys.languageCode);
    return AppSettings(
      autoStartRestTimer: flag(
        SettingsKeys.autoStartRestTimer,
        _defaults.autoStartRestTimer,
      ),
      restAlertsEnabled: flag(
        SettingsKeys.restAlertsEnabled,
        _defaults.restAlertsEnabled,
      ),
      soundEnabled: flag(SettingsKeys.soundEnabled, _defaults.soundEnabled),
      vibrationEnabled: flag(
        SettingsKeys.vibrationEnabled,
        _defaults.vibrationEnabled,
      ),
      remindersEnabled: flag(
        SettingsKeys.remindersEnabled,
        _defaults.remindersEnabled,
      ),
      reminderMinutesOfDay: minutes is int && minutes >= 0 && minutes < 1440
          ? minutes
          : _defaults.reminderMinutesOfDay,
      languageCode:
          language is String &&
              AppSettings.supportedLanguageCodes.contains(language)
          ? language
          : null,
    );
  }

  Future<void> save(AppSettings settings) async {
    ensureValid(Validators.settings(settings));
    await _storage.settings.putAll({
      SettingsKeys.autoStartRestTimer: settings.autoStartRestTimer,
      SettingsKeys.restAlertsEnabled: settings.restAlertsEnabled,
      SettingsKeys.soundEnabled: settings.soundEnabled,
      SettingsKeys.vibrationEnabled: settings.vibrationEnabled,
      SettingsKeys.remindersEnabled: settings.remindersEnabled,
      SettingsKeys.reminderMinutesOfDay: settings.reminderMinutesOfDay,
    });
    final language = settings.languageCode;
    if (language == null) {
      await _storage.settings.delete(SettingsKeys.languageCode);
    } else {
      await _storage.settings.put(SettingsKeys.languageCode, language);
    }
  }

  Stream<AppSettings> watch() => watchTriggers(triggers, settings);

  List<ChangeTrigger> get triggers => [_storage.settings.watch];

  int? schemaVersion() {
    final value = _storage.settings.get(SettingsKeys.storageSchemaVersion);
    return value is int ? value : null;
  }

  Future<void> setSchemaVersion(int version) =>
      _storage.settings.put(SettingsKeys.storageSchemaVersion, version);
}
