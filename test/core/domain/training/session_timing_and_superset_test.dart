import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/domain/training/schedule_resolver.dart';
import 'package:gainit/core/domain/training/workout_session_rules.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('WorkoutSessionRules.completionTime', () {
    final start = DateTime(2026, 3, 1, 18);

    test('uses now for a normally finished workout', () {
      final now = start.add(const Duration(minutes: 55));

      expect(
        WorkoutSessionRules.completionTime(
          startedAt: start,
          now: now,
          lastSetAt: start.add(const Duration(minutes: 50)),
        ),
        now,
      );
    });

    test('uses the last set for a workout forgotten for days', () {
      final lastSet = start.add(const Duration(minutes: 40));

      expect(
        WorkoutSessionRules.completionTime(
          startedAt: start,
          now: start.add(const Duration(days: 7)),
          lastSetAt: lastSet,
        ),
        lastSet,
      );
    });

    test('uses the start time for a forgotten workout with no sets', () {
      expect(
        WorkoutSessionRules.completionTime(
          startedAt: start,
          now: start.add(const Duration(days: 2)),
        ),
        start,
      );
    });

    test('never returns a time before the start (clock moved back)', () {
      expect(
        WorkoutSessionRules.completionTime(
          startedAt: start,
          now: start.subtract(const Duration(hours: 2)),
        ),
        start,
      );
    });
  });

  group('superset alternation', () {
    final curl = Fixtures.sessionExercise(
      id: 'curl',
      exerciseId: 'ex_curl',
      targetSets: 2,
    );
    final pushdown = Fixtures.sessionExercise(
      id: 'push',
      exerciseId: 'ex_push',
      targetSets: 2,
    );
    SessionExercise grouped(SessionExercise e, int order) => SessionExercise(
      id: e.id,
      sessionId: e.sessionId,
      programExerciseId: e.programExerciseId,
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      primaryMuscle: e.primaryMuscle,
      category: e.category,
      orderIndex: order,
      targetSets: e.targetSets,
      repMin: e.repMin,
      repMax: e.repMax,
      restSeconds: e.restSeconds,
      rirMin: e.rirMin,
      rirMax: e.rirMax,
      weightStep: e.weightStep,
      supersetGroup: 1,
    );
    final exercises = [grouped(curl, 0), grouped(pushdown, 1)];

    int? current(List<(String, int)> logged) =>
        WorkoutSessionRules.currentExerciseIndex(exercises, [
          for (final (id, n) in logged)
            Fixtures.set(sessionExerciseId: id, number: n),
        ]);

    test('alternates A1 → B1 → A2 → B2', () {
      expect(current([]), 0);
      expect(current([('curl', 1)]), 1);
      expect(current([('curl', 1), ('push', 1)]), 0);
      expect(current([('curl', 1), ('push', 1), ('curl', 2)]), 1);
      expect(
        current([('curl', 1), ('push', 1), ('curl', 2), ('push', 2)]),
        isNull,
      );
    });
  });

  group('ScheduleResolver boundaries', () {
    test('week start crosses month and year boundaries', () {
      // 2026-01-01 is a Thursday → week began Saturday 2025-12-27.
      expect(
        ScheduleResolver.weekStart(DateTime(2026, 1, 1, 10)),
        DateTime(2025, 12, 27),
      );
      // 2026-04-02 (Thursday) → Saturday 2026-03-28.
      expect(
        ScheduleResolver.weekStart(DateTime(2026, 4, 2)),
        DateTime(2026, 3, 28),
      );
    });

    test('week number counts across a year boundary', () {
      expect(
        ScheduleResolver.weekNumber(
          DateTime(2025, 12, 27),
          DateTime(2026, 1, 10),
        ),
        3,
      );
    });

    test('daysBetween counts calendar days across DST changes', () {
      // Spans the March and October DST switches in most time zones.
      expect(
        ScheduleResolver.daysBetween(
          DateTime(2026, 3, 1),
          DateTime(2026, 4, 1),
        ),
        31,
      );
      expect(
        ScheduleResolver.daysBetween(
          DateTime(2026, 10, 1),
          DateTime(2026, 11, 1),
        ),
        31,
      );
    });

    test('days before the program start are not "missed"', () {
      final sunday = Fixtures.day('sun', DateTime.sunday);
      final wednesday = DateTime(2026, 3, 4);

      final status = ScheduleResolver.statusOf(
        day: sunday,
        today: wednesday,
        completedDayIdsThisWeek: const {},
        programStart: DateTime(2026, 3, 3),
      );
      final withoutStart = ScheduleResolver.statusOf(
        day: sunday,
        today: wednesday,
        completedDayIdsThisWeek: const {},
      );

      expect(status, DayStatus.beforeStart);
      expect(withoutStart, DayStatus.missed);
    });
  });
}
