import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/domain/training/performance_comparator.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/features/workout/domain/entities/active_workout.dart';
import 'package:gainit/features/workout/domain/entities/workout_summary.dart';
import 'package:gainit/features/workout/domain/repositories/workout_repository.dart';
import 'package:gainit/features/workout/domain/usecases/get_workout_summary_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/log_set_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/start_workout_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/watch_active_workout_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixed_clock.dart';
import '../../../helpers/fixtures.dart';

class _MockWorkoutRepository extends Mock implements WorkoutRepository {}

class _FakeIds implements IdGenerator {
  @override
  String next() => 'generated-id';
}

void main() {
  late _MockWorkoutRepository repository;

  setUpAll(() => registerFallbackValue(Fixtures.set()));
  setUp(() => repository = _MockWorkoutRepository());

  group('StartWorkoutUseCase', () {
    test('starts a new session when none is active', () async {
      when(
        () => repository.getActiveSession(),
      ).thenAnswer((_) async => const ApiSuccess(null));
      when(
        () => repository.startSession('day_mon'),
      ).thenAnswer((_) async => ApiSuccess(Fixtures.session(id: 'new')));

      final result = await StartWorkoutUseCase(repository)('day_mon');

      expect(result, const ApiSuccess('new'));
    });

    test('resumes the active session of the same day', () async {
      when(
        () => repository.getActiveSession(),
      ).thenAnswer((_) async => ApiSuccess(Fixtures.session(id: 'running')));

      final result = await StartWorkoutUseCase(repository)('day_mon');

      expect(result, const ApiSuccess('running'));
      verifyNever(() => repository.startSession(any()));
    });

    test('refuses to start while another day is in progress', () async {
      when(
        () => repository.getActiveSession(),
      ).thenAnswer((_) async => ApiSuccess(Fixtures.session(dayId: 'day_sun')));

      final result = await StartWorkoutUseCase(repository)('day_mon');

      expect(
        result,
        isA<ApiFailure<String>>().having(
          (f) => f.failure,
          'failure',
          isA<InvalidStateFailure>(),
        ),
      );
    });
  });

  group('LogSetUseCase', () {
    const input = LogSetInput(
      sessionExerciseId: 'se1',
      setNumber: 1,
      weight: 32.5,
      reps: 8,
      rir: 2,
      plannedRepsMin: 6,
      plannedRepsMax: 10,
      plannedWeight: 32.5,
    );
    final clock = FixedClock(DateTime(2026, 3, 2, 18, 5));

    test('persists a valid set with a timestamp', () async {
      when(
        () => repository.saveSet(any()),
      ).thenAnswer((_) async => voidSuccess);

      final result = await LogSetUseCase(repository, clock, _FakeIds())(input);

      expect(result.isSuccess, isTrue);
      final saved =
          verify(() => repository.saveSet(captureAny())).captured.single
              as SetLog;
      expect(saved.actualWeight, 32.5);
      expect(saved.completedAt, clock.now());
      expect(saved.id, 'generated-id');
    });

    test('rejects negative reps without touching storage', () async {
      final result = await LogSetUseCase(repository, clock, _FakeIds())(
        const LogSetInput(
          sessionExerciseId: 'se1',
          setNumber: 1,
          weight: 30,
          reps: -1,
          plannedRepsMin: 6,
          plannedRepsMax: 10,
        ),
      );

      expect(
        result,
        isA<ApiFailure<void>>().having(
          (f) => f.failure,
          'failure',
          isA<ValidationFailure>(),
        ),
      );
      verifyNever(() => repository.saveSet(any()));
    });

    test('rejects a set with weight 0 without touching storage', () async {
      final result = await LogSetUseCase(repository, clock, _FakeIds())(
        const LogSetInput(
          sessionExerciseId: 'se1',
          setNumber: 1,
          weight: 0,
          reps: 8,
          plannedRepsMin: 6,
          plannedRepsMax: 10,
        ),
      );

      expect(
        result,
        isA<ApiFailure<void>>().having(
          (f) => (f.failure as ValidationFailure).errors,
          'errors',
          contains('validation.weightAboveZero'),
        ),
      );
      verifyNever(() => repository.saveSet(any()));
    });
  });

  group('WatchActiveWorkoutUseCase.build', () {
    test('attaches last performance and a progression target', () {
      final data = ActiveSessionData(
        session: Fixtures.session(),
        exercises: [Fixtures.sessionExercise()],
        sets: [Fixtures.set(number: 1, reps: 9)],
        history: {
          'ex_bench': [
            Fixtures.performance([(30, 10), (30, 10), (30, 10)]),
          ],
        },
      );

      final workout = WatchActiveWorkoutUseCase(repository).build(data);
      final bench = workout.exercises.single;

      expect(bench.lastPerformance!.topWeight, 30);
      expect(bench.recommendation.type, RecommendationType.increaseWeight);
      expect(bench.recommendation.suggestedWeight, 32.5);
      expect(bench.nextSetNumber, 2);
      // Next set repeats what was just logged in this session.
      expect(bench.suggestedWeight, 30);
      expect(workout.progress.completedSets, 1);
      expect(workout.currentIndex, 0);
    });
  });

  group('GetWorkoutSummaryUseCase.build', () {
    test('computes duration, volume and progress vs last time', () {
      final data = WorkoutSummaryData(
        session: Fixtures.session(
          status: SessionStatus.completed,
          startedAt: DateTime(2026, 3, 2, 18),
          completedAt: DateTime(2026, 3, 2, 18, 52),
        ),
        exercises: [Fixtures.sessionExercise()],
        sets: [
          Fixtures.set(number: 1, reps: 11),
          Fixtures.set(number: 2, reps: 10),
          Fixtures.set(number: 3, reps: 9),
        ],
        previous: {
          'ex_bench': Fixtures.performance([(30, 10), (30, 9), (30, 8)]),
        },
      );

      final summary = GetWorkoutSummaryUseCase(repository).build(data);

      expect(summary.duration, const Duration(minutes: 52));
      expect(summary.workingSets, 3);
      expect(summary.volume, {MuscleGroup.chest: 3});
      expect(
        summary.lines.single.comparison.outcome,
        ProgressOutcome.repsIncreased,
      );
      expect(summary.lines.single.comparison.repsDelta, 3);
    });
  });
}
