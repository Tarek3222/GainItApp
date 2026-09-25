import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/services/local_notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
  });

  tz.TZDateTime at(int day, int hour) =>
      tz.TZDateTime(tz.local, 2026, 3, day, hour);

  group('nextDaily', () {
    test('a time still ahead fires later today', () {
      expect(
        LocalNotificationService.nextDaily(
          at(2, 10),
          13 * 60,
          skipToday: false,
        ),
        at(2, 13),
      );
    });

    test('a time already passed fires tomorrow', () {
      expect(
        LocalNotificationService.nextDaily(
          at(2, 14),
          13 * 60,
          skipToday: false,
        ),
        at(3, 13),
      );
    });

    test('a goal reached today fires tomorrow', () {
      expect(
        LocalNotificationService.nextDaily(at(2, 10), 13 * 60, skipToday: true),
        at(3, 13),
      );
    });

    test('rolls over the end of the month', () {
      expect(
        LocalNotificationService.nextDaily(
          tz.TZDateTime(tz.local, 2026, 3, 31, 22),
          9 * 60,
          skipToday: false,
        ),
        tz.TZDateTime(tz.local, 2026, 4, 1, 9),
      );
    });
  });

  group('repeatsDaily', () {
    const reached = GoalReminder(
      type: DailyGoalType.water,
      title: '',
      minutesOfDay: 600,
      skipToday: true,
    );
    const pending = GoalReminder(
      type: DailyGoalType.water,
      title: '',
      minutesOfDay: 600,
    );

    test('iOS gets a one-off for tomorrow once the goal is reached', () {
      expect(
        LocalNotificationService.repeatsDaily(reached, TargetPlatform.iOS),
        isFalse,
      );
      expect(
        LocalNotificationService.repeatsDaily(pending, TargetPlatform.iOS),
        isTrue,
      );
    });

    test('Android always repeats; its first date is respected', () {
      expect(
        LocalNotificationService.repeatsDaily(reached, TargetPlatform.android),
        isTrue,
      );
    });
  });
}
