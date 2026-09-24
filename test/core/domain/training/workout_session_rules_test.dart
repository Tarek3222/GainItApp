import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/domain/training/workout_session_rules.dart';

SessionExercise exercise(String id, int sets, {bool skipped = false}) =>
    SessionExercise(
      id: id,
      sessionId: 's',
      programExerciseId: 'pe_$id',
      exerciseId: 'ex_$id',
      exerciseName: id,
      primaryMuscle: MuscleGroup.chest,
      category: ExerciseCategory.compound,
      orderIndex: 0,
      targetSets: sets,
      repMin: 6,
      repMax: 10,
      restSeconds: 120,
      rirMin: 1,
      rirMax: 3,
      weightStep: 2.5,
      isSkipped: skipped,
    );

SetLog set(String exerciseId, int number, {bool warmup = false}) => SetLog(
  id: '$exerciseId-$number',
  sessionExerciseId: exerciseId,
  setNumber: number,
  plannedRepsMin: 6,
  plannedRepsMax: 10,
  actualWeight: 30,
  actualReps: 8,
  completedAt: DateTime(2026),
  isWarmup: warmup,
);

void main() {
  group('transition', () {
    test('completes an in-progress workout', () {
      expect(
        WorkoutSessionRules.transition(
          SessionStatus.inProgress,
          SessionAction.complete,
        ),
        SessionStatus.completed,
      );
    });

    test('abandons an in-progress workout', () {
      expect(
        WorkoutSessionRules.transition(
          SessionStatus.inProgress,
          SessionAction.abandon,
        ),
        SessionStatus.abandoned,
      );
    });

    test('logging a set keeps the workout in progress', () {
      expect(
        WorkoutSessionRules.transition(
          SessionStatus.inProgress,
          SessionAction.logSet,
        ),
        SessionStatus.inProgress,
      );
    });

    test('rejects any action on a completed workout', () {
      expect(
        () => WorkoutSessionRules.transition(
          SessionStatus.completed,
          SessionAction.logSet,
        ),
        throwsStateError,
      );
    });
  });

  group('progress', () {
    test('counts working sets against the plan', () {
      final progress = WorkoutSessionRules.progress(
        [exercise('a', 3), exercise('b', 2)],
        [set('a', 1), set('a', 2), set('b', 1), set('b', 2, warmup: true)],
      );

      expect(progress.completedSets, 3);
      expect(progress.totalSets, 5);
      expect(progress.isDone, isFalse);
    });

    test('skipped exercises only count logged sets', () {
      final progress = WorkoutSessionRules.progress(
        [exercise('a', 3), exercise('b', 2, skipped: true)],
        [set('a', 1), set('a', 2), set('a', 3), set('b', 1)],
      );

      expect(progress.totalSets, 4);
      expect(progress.isDone, isTrue);
    });
  });

  test('nextSetNumber continues after the highest logged set', () {
    expect(
      WorkoutSessionRules.nextSetNumber('a', [set('a', 1), set('a', 2)]),
      3,
    );
    expect(WorkoutSessionRules.nextSetNumber('b', [set('a', 1)]), 1);
  });

  test('currentExerciseIndex resumes at the first unfinished exercise', () {
    final exercises = [
      exercise('a', 1),
      exercise('b', 1, skipped: true),
      exercise('c', 2),
    ];

    expect(
      WorkoutSessionRules.currentExerciseIndex(exercises, [set('a', 1)]),
      2,
    );
    expect(
      WorkoutSessionRules.currentExerciseIndex(exercises, [
        set('a', 1),
        set('c', 1),
        set('c', 2),
      ]),
      isNull,
    );
  });
}
