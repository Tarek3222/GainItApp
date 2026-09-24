import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/training/volume_calculator.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/local_data_sources/body_weight_local_data_source.dart';
import '../../../../core/storage/local_data_sources/program_local_data_source.dart';
import '../../../../core/storage/local_data_sources/workout_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/progress_entities.dart';
import '../../domain/repositories/progress_repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  const ProgressRepositoryImpl(this._programs, this._workouts, this._weights);

  final ProgramLocalDataSource _programs;
  final WorkoutLocalDataSource _workouts;
  final BodyWeightLocalDataSource _weights;

  @override
  Stream<ApiResult<ProgressData>> watchProgressData() => guardStream(
    watchTriggers([
      ..._programs.triggers,
      ..._workouts.triggers,
      ..._weights.triggers,
    ], _load),
  );

  ProgressData _load() {
    final index = _workouts.snapshot();
    final completed = _workouts.sessions(status: SessionStatus.completed);
    final loggedSets = <VolumeSetEntry>[];
    final exercises = <String, ExerciseRef>{};

    for (final session in completed) {
      final exercisesOfSession = index.exercisesOf(session.id);
      final muscleOf = {
        for (final e in exercisesOfSession) e.id: e.primaryMuscle,
      };
      final sets = index.setsOf(session.id);
      final logged = sets.map((s) => s.sessionExerciseId).toSet();
      for (final e in exercisesOfSession) {
        if (logged.contains(e.id)) {
          exercises.putIfAbsent(
            e.exerciseId,
            () => (
              id: e.exerciseId,
              name: e.exerciseName,
              muscle: e.primaryMuscle,
            ),
          );
        }
      }
      for (final set in sets) {
        final muscle = muscleOf[set.sessionExerciseId];
        if (muscle == null) continue;
        loggedSets.add(
          VolumeSetEntry(
            muscle: muscle,
            completedAt: set.completedAt,
            sessionStatus: session.status,
            isWarmup: set.isWarmup,
          ),
        );
      }
    }

    final program = _programs.activeProgram();
    final plannedConfig = <({MuscleGroup muscle, int sets})>[];
    if (program != null) {
      for (final day in _programs.days(program.id)) {
        // Rest days keep their exercises for later but aren't trained.
        if (!day.isWorkout) continue;
        for (final pe in _programs.programExercisesForDay(day.id)) {
          final exercise = _programs.exercise(pe.exerciseId);
          if (exercise == null) continue;
          plannedConfig.add((
            muscle: exercise.primaryMuscle,
            sets: pe.workingSets,
          ));
        }
      }
    }

    return ProgressData(
      weights: _weights.entries(),
      loggedSets: loggedSets,
      plannedConfig: plannedConfig,
      exercisesWithHistory: exercises.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<ApiResult<ExerciseHistoryData>> getExerciseHistory(
    String exerciseId,
  ) => guardStorage(() {
    final exercise =
        _programs.exercise(exerciseId) ??
        (throw NotFoundException('Exercise $exerciseId not found.'));
    return ExerciseHistoryData(
      exercise: (
        id: exercise.id,
        name: exercise.name,
        muscle: exercise.primaryMuscle,
      ),
      sessions: _workouts.performances(exerciseId),
    );
  });
}
