import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/daily_goal.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/goals/goal_reminder_planner.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';

void main() {
  DailyGoal goal(
    String id, {
    bool reminders = true,
    int every = 120,
    int from = 9 * 60,
    int until = 21 * 60,
    DailyGoalType type = DailyGoalType.water,
  }) => DailyGoal(
    id: id,
    type: type,
    target: 3000,
    sortOrder: 0,
    createdAt: DateTime(2026),
    title: id,
    reminderEnabled: reminders,
    reminderIntervalMinutes: every,
    reminderStartMinutes: from,
    reminderEndMinutes: until,
  );

  test('reminders repeat from the first to the last time, inclusive', () {
    expect(goal('w').reminderTimes, [for (var h = 9; h <= 21; h += 2) h * 60]);
  });

  test('the last reminder is the last slot that fits before the end', () {
    expect(goal('w', every: 180, from: 9 * 60, until: 20 * 60).reminderTimes, [
      9 * 60,
      12 * 60,
      15 * 60,
      18 * 60,
    ]);
  });

  test('goals without reminders plan nothing', () {
    expect(GoalReminderPlanner.plan([goal('w', reminders: false)]), isEmpty);
  });

  test('goals reached today start again tomorrow', () {
    final plan = GoalReminderPlanner.plan(
      [
        goal('w', until: 11 * 60),
        goal('c', type: DailyGoalType.custom, until: 9 * 60),
      ],
      completedToday: {'w'},
    );

    expect(plan, [
      const GoalReminder(
        type: DailyGoalType.water,
        title: 'w',
        minutesOfDay: 9 * 60,
        skipToday: true,
      ),
      const GoalReminder(
        type: DailyGoalType.water,
        title: 'w',
        minutesOfDay: 11 * 60,
        skipToday: true,
      ),
      const GoalReminder(
        type: DailyGoalType.custom,
        title: 'c',
        minutesOfDay: 9 * 60,
      ),
    ]);
  });

  test('never plans more than the platform allows', () {
    final plan = GoalReminderPlanner.plan([
      goal('a', every: 30, from: 0, until: 23 * 60 + 30),
      goal('b', every: 30, from: 0, until: 23 * 60 + 30),
    ]);

    expect(plan, hasLength(NotificationScheduler.maxGoalReminders));
    expect(plan.every((r) => r.title == 'a'), isTrue);
  });
}
