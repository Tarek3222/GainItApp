import 'package:equatable/equatable.dart';

import '../entities/enums.dart';

/// One daily reminder for a goal, repeated at [minutesOfDay] every day.
class GoalReminder extends Equatable {
  const GoalReminder({
    required this.type,
    required this.title,
    required this.minutesOfDay,
    this.skipToday = false,
  });

  final DailyGoalType type;

  /// Name of a custom goal; empty for water and steps.
  final String title;
  final int minutesOfDay;

  /// The goal is already reached today, so the first reminder is tomorrow.
  final bool skipToday;

  @override
  List<Object?> get props => [type, title, minutesOfDay, skipToday];
}

/// Abstraction over platform notifications so use cases stay testable and
/// screens never schedule notifications directly (spec §21).
abstract interface class NotificationScheduler {
  /// iOS keeps only 64 pending notifications per app; goal reminders get
  /// most of them, the rest timer and workout reminders use the others.
  static const maxGoalReminders = 48;

  /// Language code the notification texts are written in right now.
  /// Reminders scheduled in another language need rescheduling.
  String get textLanguage;

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

  /// Daily goal reminders. Replaces previous goal reminders; at most
  /// [maxGoalReminders] are scheduled.
  Future<void> scheduleGoalReminders(List<GoalReminder> reminders);

  Future<void> cancelGoalReminders();

  /// Returns whether notifications are permitted after asking.
  Future<bool> requestPermission();
}
