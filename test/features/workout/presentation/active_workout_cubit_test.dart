import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';
import 'package:gainit/core/domain/training/workout_session_rules.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/features/workout/domain/entities/active_workout.dart';
import 'package:gainit/features/workout/domain/usecases/log_set_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/session_actions_use_cases.dart';
import 'package:gainit/features/workout/domain/usecases/watch_active_workout_use_case.dart';
import 'package:gainit/features/workout/presentation/cubits/active_workout_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class _MockWatch extends Mock implements WatchActiveWorkoutUseCase {}

class _MockLogSet extends Mock implements LogSetUseCase {}

class _MockUndo extends Mock implements UndoSetUseCase {}

class _MockSkip extends Mock implements SkipExerciseUseCase {}

class _MockFinish extends Mock implements FinishWorkoutUseCase {}

class _MockAbandon extends Mock implements AbandonWorkoutUseCase {}

ActiveWorkout workout({SessionStatus status = SessionStatus.inProgress}) {
  return ActiveWorkout(
    session: Fixtures.session(status: status),
    exercises: [
      ActiveExercise(
        snapshot: Fixtures.sessionExercise(),
        sets: const [],
        recommendation: const Recommendation(
          type: RecommendationType.firstSession,
          repMin: 6,
          repMax: 10,
        ),
      ),
    ],
    progress: const WorkoutProgress(completedSets: 0, totalSets: 3),
    currentIndex: 0,
  );
}

void main() {
  late _MockWatch watch;
  late _MockLogSet logSet;
  late _MockFinish finish;
  late StreamController<ApiResult<ActiveWorkout>> stream;

  setUpAll(() {
    registerFallbackValue(
      const LogSetInput(
        sessionExerciseId: '',
        setNumber: 1,
        weight: 0,
        reps: 0,
        plannedRepsMin: 1,
        plannedRepsMax: 1,
      ),
    );
  });

  setUp(() {
    watch = _MockWatch();
    logSet = _MockLogSet();
    finish = _MockFinish();
    stream = StreamController<ApiResult<ActiveWorkout>>.broadcast();
    when(() => watch('s1')).thenAnswer((_) => stream.stream);
  });

  tearDown(() => stream.close());

  ActiveWorkoutCubit build() => ActiveWorkoutCubit(
    sessionId: 's1',
    watchWorkout: watch,
    logSet: logSet,
    undoSet: _MockUndo(),
    skipExercise: _MockSkip(),
    finishWorkout: finish,
    abandonWorkout: _MockAbandon(),
  );

  blocTest<ActiveWorkoutCubit, ActiveWorkoutState>(
    'emits Loaded when the workout stream delivers data',
    build: build,
    act: (cubit) {
      cubit.start();
      stream.add(ApiSuccess(workout()));
    },
    expect: () => [
      const ActiveWorkoutLoading(),
      ActiveWorkoutLoaded(workout: workout()),
    ],
  );

  blocTest<ActiveWorkoutCubit, ActiveWorkoutState>(
    'emits Error when the first load fails',
    build: build,
    act: (cubit) {
      cubit.start();
      stream.add(const ApiFailure(StorageFailure()));
    },
    expect: () => [const ActiveWorkoutLoading(), isA<ActiveWorkoutError>()],
  );

  blocTest<ActiveWorkoutCubit, ActiveWorkoutState>(
    'shows a message and returns false when saving a set fails',
    setUp: () => when(() => logSet(any())).thenAnswer(
      (_) async =>
          const ApiFailure(ValidationFailure(['Reps cannot be negative.'])),
    ),
    build: build,
    seed: () => ActiveWorkoutLoaded(workout: workout()),
    act: (cubit) async {
      final saved = await cubit.logSet(
        exercise: workout().exercises.first,
        weight: 30,
        reps: -1,
      );
      expect(saved, isFalse);
    },
    expect: () => [
      ActiveWorkoutLoaded(
        workout: workout(),
        message: 'Reps cannot be negative.',
        messageId: 1,
      ),
    ],
  );

  blocTest<ActiveWorkoutCubit, ActiveWorkoutState>(
    'builds the set input from the exercise snapshot',
    setUp: () => when(() => logSet(any())).thenAnswer((_) async => voidSuccess),
    build: build,
    seed: () => ActiveWorkoutLoaded(workout: workout()),
    act: (cubit) => cubit.logSet(
      exercise: workout().exercises.first,
      weight: 32.5,
      reps: 8,
      rir: 2,
    ),
    verify: (_) {
      final input =
          verify(() => logSet(captureAny())).captured.single as LogSetInput;
      expect(input.sessionExerciseId, 'se1');
      expect(input.setNumber, 1);
      expect(input.plannedRepsMin, 6);
      expect(input.rir, 2);
    },
  );

  blocTest<ActiveWorkoutCubit, ActiveWorkoutState>(
    'emits Closed(completed) after finishing',
    setUp: () => when(() => finish('s1')).thenAnswer(
      (_) async =>
          ApiSuccess(Fixtures.session(status: SessionStatus.completed)),
    ),
    build: build,
    seed: () => ActiveWorkoutLoaded(workout: workout()),
    act: (cubit) => cubit.finish(),
    expect: () => [const ActiveWorkoutClosed(sessionId: 's1', completed: true)],
  );

  blocTest<ActiveWorkoutCubit, ActiveWorkoutState>(
    'closes when the session is already finished (e.g. opened late)',
    build: build,
    act: (cubit) {
      cubit.start();
      stream.add(ApiSuccess(workout(status: SessionStatus.completed)));
    },
    expect: () => [
      const ActiveWorkoutLoading(),
      const ActiveWorkoutClosed(sessionId: 's1', completed: true),
    ],
  );

  test('finishing after the screen closed does not throw', () async {
    final completer = Completer<ApiResult<WorkoutSession>>();
    when(() => finish('s1')).thenAnswer((_) => completer.future);
    final cubit = build();

    final pending = cubit.finish();
    await cubit.close();
    completer.complete(
      ApiSuccess(Fixtures.session(status: SessionStatus.completed)),
    );

    await expectLater(pending, completes);
  });
}
