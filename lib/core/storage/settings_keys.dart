/// Keys of the untyped `settings` box. Always add keys here, never inline.
abstract final class SettingsKeys {
  static const storageSchemaVersion = 'storage_schema_version';
  static const autoStartRestTimer = 'auto_start_rest_timer';
  static const restAlertsEnabled = 'rest_alerts_enabled';
  static const soundEnabled = 'sound_enabled';
  static const vibrationEnabled = 'vibration_enabled';
  static const remindersEnabled = 'reminders_enabled';
  static const reminderMinutesOfDay = 'reminder_minutes_of_day';

  /// The default daily goals were added once; removed ones stay removed.
  static const dailyGoalsSeeded = 'daily_goals_seeded';

  /// Step sensor state (see `StepTrackerState`).
  static const stepTrackerDayKey = 'step_tracker_day_key';
  static const stepTrackerBaseline = 'step_tracker_baseline';
  static const stepTrackerLastCount = 'step_tracker_last_count';

  /// What the goal reminders were last scheduled from, so an unchanged
  /// plan isn't rescheduled on every launch.
  static const goalReminderPlan = 'goal_reminder_plan';
}

/// Key of the single profile record in the `user_profile` box.
const kProfileKey = 'me';
