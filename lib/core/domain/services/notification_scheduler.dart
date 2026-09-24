/// Abstraction over platform notifications so use cases stay testable and
/// screens never schedule notifications directly (spec §21).
abstract interface class NotificationScheduler {
  /// Shows a live countdown and alerts when rest is over.
  Future<void> scheduleRestOver({
    required DateTime endsAt,
    required String exerciseName,
  });

  Future<void> cancelRestOver();

  /// Weekly reminders on the given weekdays ([DateTime.weekday]) at a local
  /// time expressed in minutes after midnight. Replaces previous reminders.
  Future<void> scheduleWorkoutReminders({
    required List<({int weekday, String workoutName})> days,
    required int minutesOfDay,
  });

  Future<void> cancelWorkoutReminders();

  /// Returns whether notifications are permitted after asking.
  Future<bool> requestPermission();
}
