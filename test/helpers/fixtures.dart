import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/domain/training/performance.dart';

/// Small builders shared by tests.
abstract final class Fixtures {
  static WorkoutSession session({
    String id = 's1',
    String dayId = 'day_mon',
    String name = 'Legs',
    DateTime? startedAt,
    DateTime? completedAt,
    SessionStatus status = SessionStatus.inProgress,
  }) => WorkoutSession(
    id: id,
    programId: 'p1',
    workoutDayId: dayId,
    workoutName: name,
    startedAt: startedAt ?? DateTime(2026, 3, 2, 18),
    completedAt: completedAt,
    status: status,
  );

  static SessionExercise sessionExercise({
    String id = 'se1',
    String sessionId = 's1',
    String exerciseId = 'ex_bench',
    String name = 'Bench Press',
    MuscleGroup muscle = MuscleGroup.chest,
    int targetSets = 3,
    int repMin = 6,
    int repMax = 10,
    int restSeconds = 120,
    bool skipped = false,
  }) => SessionExercise(
    id: id,
    sessionId: sessionId,
    programExerciseId: 'pe_$exerciseId',
    exerciseId: exerciseId,
    exerciseName: name,
    primaryMuscle: muscle,
    category: ExerciseCategory.compound,
    orderIndex: 0,
    targetSets: targetSets,
    repMin: repMin,
    repMax: repMax,
    restSeconds: restSeconds,
    rirMin: 1,
    rirMax: 3,
    weightStep: 2.5,
    isSkipped: skipped,
  );

  static SetLog set({
    String? id,
    String sessionExerciseId = 'se1',
    int number = 1,
    double weight = 30,
    int reps = 8,
    DateTime? at,
  }) => SetLog(
    id: id ?? '$sessionExerciseId-$number',
    sessionExerciseId: sessionExerciseId,
    setNumber: number,
    plannedRepsMin: 6,
    plannedRepsMax: 10,
    actualWeight: weight,
    actualReps: reps,
    completedAt: at ?? DateTime(2026, 3, 2, 18, 10),
  );

  static ExerciseSessionPerformance performance(
    List<(double, int)> sets, {
    String sessionId = 'old',
    DateTime? date,
  }) => ExerciseSessionPerformance(
    sessionId: sessionId,
    date: date ?? DateTime(2026, 2, 23),
    sets: [for (final (w, r) in sets) SetPerformance(weight: w, reps: r)],
  );

  static WorkoutDay day(String id, int weekday, {bool workout = true}) =>
      WorkoutDay(
        id: id,
        programId: 'p1',
        weekday: weekday,
        name: id,
        type: workout ? DayType.workout : DayType.rest,
        sortOrder: (weekday - DateTime.saturday) % 7,
      );

  static Program program({DateTime? startDate}) => Program(
    id: 'p1',
    name: 'Hypertrophy',
    description: '',
    isActive: true,
    startDate: startDate ?? DateTime(2026, 2, 1),
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 2, 1),
  );
}
