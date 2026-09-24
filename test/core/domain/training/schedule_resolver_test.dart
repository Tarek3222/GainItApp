import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/training/schedule_resolver.dart';

WorkoutDay day(String id, int weekday, {bool workout = true}) => WorkoutDay(
  id: id,
  programId: 'p',
  weekday: weekday,
  name: id,
  type: workout ? DayType.workout : DayType.rest,
  sortOrder: ScheduleResolver.offsetInWeek(weekday),
);

void main() {
  final days = [
    day('sat', DateTime.saturday, workout: false),
    day('sun', DateTime.sunday),
    day('mon', DateTime.monday),
    day('tue', DateTime.tuesday, workout: false),
    day('wed', DateTime.wednesday),
    day('thu', DateTime.thursday),
    day('fri', DateTime.friday, workout: false),
  ];

  // 2026-03-02 is a Monday.
  final monday = DateTime(2026, 3, 2, 9);

  group('weekStart', () {
    test('starts the week on Saturday', () {
      expect(ScheduleResolver.weekStart(monday), DateTime(2026, 2, 28));
    });

    test('a Saturday is its own week start', () {
      expect(
        ScheduleResolver.weekStart(DateTime(2026, 2, 28, 23)),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('weekNumber', () {
    test('is 1 during the first week', () {
      expect(ScheduleResolver.weekNumber(DateTime(2026, 3, 1), monday), 1);
    });

    test('counts whole Saturday-based weeks', () {
      expect(ScheduleResolver.weekNumber(DateTime(2026, 2, 1), monday), 5);
    });

    test('never goes below 1 when start is in the future', () {
      expect(ScheduleResolver.weekNumber(DateTime(2027, 1, 1), monday), 1);
    });
  });

  group('nextWorkout', () {
    test('returns today when today is an unfinished workout day', () {
      final next = ScheduleResolver.nextWorkout(
        days: days,
        today: monday,
        completedDayIdsThisWeek: {'sun'},
      );

      expect(next!.day.id, 'mon');
      expect(next.isToday, isTrue);
    });

    test('skips today once completed', () {
      final next = ScheduleResolver.nextWorkout(
        days: days,
        today: monday,
        completedDayIdsThisWeek: {'sun', 'mon'},
      );

      expect(next!.day.id, 'wed');
      expect(next.date, DateTime(2026, 3, 4));
    });

    test('rolls over to next week after the last workout day', () {
      final friday = DateTime(2026, 3, 6);
      final next = ScheduleResolver.nextWorkout(
        days: days,
        today: friday,
        completedDayIdsThisWeek: const {},
      );

      expect(next!.day.id, 'sun');
      expect(next.date, DateTime(2026, 3, 8));
    });

    test('returns null when the program has no workout days', () {
      final next = ScheduleResolver.nextWorkout(
        days: [day('rest', DateTime.monday, workout: false)],
        today: monday,
        completedDayIdsThisWeek: const {},
      );

      expect(next, isNull);
    });
  });

  group('statusOf', () {
    DayStatus status(String id, Set<String> done) => ScheduleResolver.statusOf(
      day: days.firstWhere((d) => d.id == id),
      today: monday,
      completedDayIdsThisWeek: done,
    );

    test('marks rest, completed, today, missed and upcoming days', () {
      expect(status('sat', const {}), DayStatus.rest);
      expect(status('sun', {'sun'}), DayStatus.completed);
      expect(status('sun', const {}), DayStatus.missed);
      expect(status('mon', const {}), DayStatus.today);
      expect(status('wed', const {}), DayStatus.upcoming);
    });
  });
}
