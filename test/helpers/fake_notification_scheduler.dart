import 'package:gainit/core/domain/services/notification_scheduler.dart';

/// Records what would be scheduled, for use-case tests.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({this.permissionGranted = true});

  bool permissionGranted;
  var permissionRequests = 0;

  /// Goal reminders from the latest schedule call; `null` after a cancel.
  List<GoalReminder>? goalReminders;
  var goalScheduleCalls = 0;
  var goalCancelCalls = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleGoalReminders(List<GoalReminder> reminders) async {
    goalScheduleCalls++;
    goalReminders = reminders;
  }

  @override
  Future<void> cancelGoalReminders() async {
    goalCancelCalls++;
    goalReminders = null;
  }

  @override
  Future<void> scheduleRestOver({
    required DateTime endsAt,
    required String exerciseName,
  }) async {}

  @override
  Future<void> cancelRestOver() async {}

  @override
  Future<void> scheduleWorkoutReminders({
    required List<({int weekday, String workoutName})> days,
    required int minutesOfDay,
  }) async {}

  @override
  Future<void> cancelWorkoutReminders() async {}
}
