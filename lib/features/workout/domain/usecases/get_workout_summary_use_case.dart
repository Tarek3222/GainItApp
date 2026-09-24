import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/domain/training/performance_comparator.dart';
import '../../../../core/domain/training/volume_calculator.dart';
import '../../../../core/result/api_result.dart';
import '../entities/workout_summary.dart';
import '../repositories/workout_repository.dart';

class GetWorkoutSummaryUseCase {
  const GetWorkoutSummaryUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<ApiResult<WorkoutSummary>> call(String sessionId) async {
    final result = await _repository.getSummaryData(sessionId);
    return result.map(build);
  }

  WorkoutSummary build(WorkoutSummaryData data) {
    final session = data.session;
    final working = data.sets.where((s) => !s.isWarmup).toList();
    final byExercise = <String, List<SetLog>>{};
    for (final set in working) {
      byExercise.putIfAbsent(set.sessionExerciseId, () => []).add(set);
    }

    final muscleOf = {for (final e in data.exercises) e.id: e.primaryMuscle};
    final volume = VolumeCalculator.directSets([
      for (final set in working)
        if (muscleOf[set.sessionExerciseId] case final muscle?)
          VolumeSetEntry(
            muscle: muscle,
            completedAt: set.completedAt,
            sessionStatus: session.status,
          ),
    ]);

    final lines = <ExerciseProgressLine>[];
    for (final exercise in data.exercises) {
      final sets = byExercise[exercise.id];
      if (sets == null || sets.isEmpty) continue;
      sets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
      final current = ExerciseSessionPerformance(
        sessionId: session.id,
        date: session.completedAt ?? session.startedAt,
        sets: [
          for (final s in sets)
            SetPerformance(
              weight: s.actualWeight,
              reps: s.actualReps,
              rir: s.rir,
            ),
        ],
      );
      final previous = data.previous[exercise.exerciseId];
      lines.add(
        ExerciseProgressLine(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          current: current,
          previous: previous,
          comparison: PerformanceComparator.compare(
            current: current,
            previous: previous,
          ),
        ),
      );
    }

    final end = session.completedAt ?? session.startedAt;
    return WorkoutSummary(
      sessionId: session.id,
      workoutName: session.workoutName,
      duration: end.difference(session.startedAt),
      workingSets: working.length,
      volume: volume,
      lines: lines,
    );
  }
}
