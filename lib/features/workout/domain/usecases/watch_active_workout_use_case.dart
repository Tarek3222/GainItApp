import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/repositories/unit_preference_repository.dart';
import '../../../../core/domain/training/progression_engine.dart';
import '../../../../core/domain/training/workout_session_rules.dart';
import '../../../../core/domain/utils/combine_results.dart';
import '../../../../core/result/api_result.dart';
import '../entities/active_workout.dart';
import '../repositories/workout_repository.dart';

/// Streams the active workout with a progression target for every exercise.
class WatchActiveWorkoutUseCase {
  const WatchActiveWorkoutUseCase(
    this._repository, {
    this._units,
    this._engine = const ProgressionEngine(),
  });

  final WorkoutRepository _repository;

  /// Targets follow the user's unit; metric when not provided.
  final UnitPreferenceRepository? _units;
  final ProgressionEngine _engine;

  Stream<ApiResult<ActiveWorkout>> call(String sessionId) {
    final session = _repository.watchSession(sessionId);
    final units = _units;
    if (units == null) return session.map((r) => r.map(build));
    return combineResults(session, units.watch(), build);
  }

  ActiveWorkout build(
    ActiveSessionData data, [
    UnitSystem unitSystem = UnitSystem.metric,
  ]) {
    return ActiveWorkout(
      session: data.session,
      exercises: [
        for (final snapshot in data.exercises)
          _exercise(snapshot, data, unitSystem),
      ],
      progress: WorkoutSessionRules.progress(data.exercises, data.sets),
      currentIndex: WorkoutSessionRules.currentExerciseIndex(
        data.exercises,
        data.sets,
      ),
    );
  }

  ActiveExercise _exercise(
    SessionExercise snapshot,
    ActiveSessionData data,
    UnitSystem unitSystem,
  ) {
    final history = data.history[snapshot.exerciseId] ?? const [];
    final sets =
        data.sets
            .where((s) => s.sessionExerciseId == snapshot.id && !s.isWarmup)
            .toList()
          ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    return ActiveExercise(
      snapshot: snapshot,
      sets: sets,
      lastPerformance: history.isEmpty ? null : history.first,
      recommendation: _engine.recommend(
        config: ProgressionConfig(
          workingSets: snapshot.targetSets,
          repMin: snapshot.repMin,
          repMax: snapshot.repMax,
          weightStep: snapshot.weightStep,
          unitSystem: unitSystem,
        ),
        history: history,
      ),
    );
  }
}
