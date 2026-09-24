/// Keys of the untyped `settings` box. Always add keys here, never inline.
abstract final class SettingsKeys {
  static const storageSchemaVersion = 'storage_schema_version';
  static const autoStartRestTimer = 'auto_start_rest_timer';
  static const restAlertsEnabled = 'rest_alerts_enabled';
  static const soundEnabled = 'sound_enabled';
  static const vibrationEnabled = 'vibration_enabled';
  static const remindersEnabled = 'reminders_enabled';
  static const reminderMinutesOfDay = 'reminder_minutes_of_day';
}

/// Key of the single profile record in the `user_profile` box.
const kProfileKey = 'me';
