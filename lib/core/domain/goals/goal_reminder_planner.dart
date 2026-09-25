import 'dart:convert';

import '../entities/daily_goal.dart';
import '../services/notification_scheduler.dart';

/// Turns goals into the daily reminders to schedule.
abstract final class GoalReminderPlanner {
  /// Reminders of every goal with reminders on, in goal order, capped at
  /// [NotificationScheduler.maxGoalReminders]. Goals in [completedToday]
  /// start reminding again tomorrow.
  static List<GoalReminder> plan(
    List<DailyGoal> goals, {
    Set<String> completedToday = const {},
  }) {
    final reminders = <GoalReminder>[];
    for (final goal in goals) {
      for (final minutes in goal.reminderTimes) {
        if (reminders.length == NotificationScheduler.maxGoalReminders) {
          return reminders;
        }
        reminders.add(
          GoalReminder(
            type: goal.type,
            title: goal.title,
            minutesOfDay: minutes,
            skipToday: completedToday.contains(goal.id),
          ),
        );
      }
    }
    return reminders;
  }

  /// Identifies a plan, to skip rescheduling one that is already set.
  /// A plan that skips today is only valid on [dayKey], so the day is part
  /// of its key; the next day's plan always differs and is rescheduled.
  static String planKey(List<GoalReminder> reminders, {required int dayKey}) =>
      jsonEncode({
        if (reminders.any((r) => r.skipToday)) 'day': dayKey,
        'reminders': [
          for (final r in reminders)
            [r.type.index, r.title, r.minutesOfDay, r.skipToday],
        ],
      });
}
