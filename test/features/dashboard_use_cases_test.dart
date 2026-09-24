import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/body_weight_entry.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/services/day_change_source.dart';
import 'package:gainit/core/domain/training/schedule_resolver.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/features/home/domain/entities/home_dashboard.dart';
import 'package:gainit/features/home/domain/repositories/home_repository.dart';
import 'package:gainit/features/home/domain/usecases/watch_home_dashboard_use_case.dart';
import 'package:gainit/features/program/domain/entities/plan_entities.dart';
import 'package:gainit/features/program/domain/repositories/program_repository.dart';
import 'package:gainit/features/program/domain/usecases/watch_weekly_plan_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixed_clock.dart';
import '../helpers/fixtures.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

class _MockProgramRepository extends Mock implements ProgramRepository {}

class _NoDayChanges implements DayChangeSource {
  @override
  Stream<void> get changes => const Stream.empty();
}

class _TickDayChanges implements DayChangeSource {
  _TickDayChanges(this.changes);

  @override
  final Stream<void> changes;
}

void main() {
  // Monday 2026-03-02, 19:00.
  final clock = FixedClock(DateTime(2026, 3, 2, 19));
  final days = [
    Fixtures.day('day_sat', DateTime.saturday, workout: false),
    Fixtures.day('day_sun', DateTime.sunday),
    Fixtures.day('day_mon', DateTime.monday),
    Fixtures.day('day_wed', DateTime.wednesday),
    Fixtures.day('day_thu', DateTime.thursday),
  ];
  final sundayDone = Fixtures.session(
    id: 'sun1',
    dayId: 'day_sun',
    name: 'Chest + Back',
    status: SessionStatus.completed,
    startedAt: DateTime(2026, 3, 1, 18),
    completedAt: DateTime(2026, 3, 1, 19),
  );

  group('WatchHomeDashboardUseCase.build', () {
    HomeData data({
      List<BodyWeightEntry> weights = const [],
      List<ExercisePerformancePair> last = const [],
      Map<String, int> exerciseCounts = const {
        'day_sun': 7,
        'day_mon': 6,
        'day_wed': 7,
        'day_thu': 7,
      },
    }) => HomeData(
      profile: null,
      program: Fixtures.program(startDate: DateTime(2026, 2, 1)),
      days: days,
      plannedSetsPerDay: const {'day_mon': 20},
      exerciseCountPerDay: exerciseCounts,
      completedSessions: [sundayDone],
      workingSetsPerSession: const {'sun1': 19},
      weights: weights,
      lastSessionExercises: last,
    );

    test('shows today as the next workout with its set count', () {
      final dashboard = WatchHomeDashboardUseCase(
        _MockHomeRepository(),
        clock,
        _NoDayChanges(),
      ).build(data());

      expect(dashboard.greeting, 'Good evening');
      expect(dashboard.nextWorkout!.dayId, 'day_mon');
      expect(dashboard.nextWorkout!.isToday, isTrue);
      expect(dashboard.nextWorkout!.totalSets, 20);
    });

    test('skips a workout day that has no exercises', () {
      final dashboard =
          WatchHomeDashboardUseCase(
            _MockHomeRepository(),
            clock,
            _NoDayChanges(),
          ).build(
            data(
              exerciseCounts: const {'day_sun': 7, 'day_wed': 7, 'day_thu': 7},
            ),
          );

      expect(dashboard.nextWorkout!.dayId, 'day_wed');
      expect(dashboard.weekPlannedWorkouts, 3);
    });

    test('counts this week\'s completed workouts and working sets', () {
      final dashboard = WatchHomeDashboardUseCase(
        _MockHomeRepository(),
        clock,
        _NoDayChanges(),
      ).build(data());

      expect(dashboard.weekCompletedWorkouts, 1);
      expect(dashboard.weekPlannedWorkouts, 4);
      expect(dashboard.weekWorkingSets, 19);
      expect(dashboard.weekNumber, 5);
    });

    test('prefers an improved exercise for "last progress"', () {
      final dashboard =
          WatchHomeDashboardUseCase(
            _MockHomeRepository(),
            clock,
            _NoDayChanges(),
          ).build(
            data(
              last: [
                (
                  exerciseId: 'row',
                  name: 'Row',
                  current: Fixtures.performance([(40, 8)]),
                  previous: Fixtures.performance([(40, 8)]),
                ),
                (
                  exerciseId: 'bench',
                  name: 'Bench Press',
                  current: Fixtures.performance([(30, 11), (30, 10)]),
                  previous: Fixtures.performance([(30, 10), (30, 9)]),
                ),
              ],
            ),
          );

      expect(dashboard.lastProgress!.exerciseName, 'Bench Press');
    });

    test('recomputes "today" when the day changes without new data', () async {
      final repository = _MockHomeRepository();
      final ticks = StreamController<void>.broadcast();
      final dayClock = FixedClock(DateTime(2026, 3, 2, 23, 59)); // Monday
      when(
        repository.watchHomeData,
      ).thenAnswer((_) => Stream.value(ApiSuccess(data())));
      final useCase = WatchHomeDashboardUseCase(
        repository,
        dayClock,
        _TickDayChanges(ticks.stream),
      );

      final emitted = <String?>[];
      final sub = useCase().listen(
        (r) => emitted.add(
          (r as ApiSuccess<HomeDashboard>).data.nextWorkout?.dayId,
        ),
      );
      await pumpEventQueue();
      dayClock.current = DateTime(2026, 3, 3, 0, 1); // Tuesday
      ticks.add(null);
      await pumpEventQueue();

      expect(emitted, ['day_mon', 'day_wed']);
      await sub.cancel();
      await ticks.close();
    });
  });

  group('WatchWeeklyPlanUseCase.build', () {
    test('marks statuses and totals for the current week', () {
      final plan =
          WatchWeeklyPlanUseCase(
            _MockProgramRepository(),
            clock,
            _NoDayChanges(),
          ).build(
            WeekPlanData(
              program: Fixtures.program(),
              days: days,
              dayExercises: const {
                'day_mon': [
                  ProgramExercise(
                    id: 'pe',
                    workoutDayId: 'day_mon',
                    exerciseId: 'ex',
                    orderIndex: 0,
                    workingSets: 4,
                    repMin: 6,
                    repMax: 10,
                    restMinSeconds: 180,
                    restMaxSeconds: 180,
                    rirMin: 1,
                    rirMax: 3,
                    weightStep: 2.5,
                  ),
                ],
              },
              completedSessions: [sundayDone],
            ),
          );

      DayStatus status(String id) =>
          plan.days.firstWhere((d) => d.day.id == id).status;

      expect(plan.days.first.day.id, 'day_sat');
      expect(status('day_sat'), DayStatus.rest);
      expect(status('day_sun'), DayStatus.completed);
      expect(status('day_mon'), DayStatus.today);
      expect(status('day_wed'), DayStatus.upcoming);
      expect(plan.days.firstWhere((d) => d.day.id == 'day_mon').totalSets, 4);
      expect(plan.completedWorkouts, 1);
    });
  });
}
