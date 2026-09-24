import '../../../../core/domain/training/progression_engine.dart';
import '../../../../core/domain/training/volume_calculator.dart';
import '../../../../core/result/api_result.dart';
import '../entities/plan_entities.dart';
import '../repositories/program_repository.dart';

/// Workout details before starting: targets, last result, recommendation.
class WatchWorkoutOverviewUseCase {
  const WatchWorkoutOverviewUseCase(
    this._repository, [
    this._engine = const ProgressionEngine(),
  ]);

  final ProgramRepository _repository;
  final ProgressionEngine _engine;

  Stream<ApiResult<WorkoutOverview>> call(String dayId) =>
      _repository.watchWorkoutDay(dayId).map((r) => r.map(build));

  WorkoutOverview build(WorkoutDayData data) {
    final exercises = [
      for (final item in data.items)
        OverviewExercise(
          exerciseId: item.exercise.id,
          name: item.exercise.name,
          primaryMuscle: item.exercise.primaryMuscle,
          config: item.config,
          lastPerformance: item.history.isEmpty ? null : item.history.first,
          recommendation: _engine.recommend(
            config: ProgressionConfig(
              workingSets: item.config.workingSets,
              repMin: item.config.repMin,
              repMax: item.config.repMax,
              weightStep: item.config.weightStep,
            ),
            history: item.history,
          ),
        ),
    ];
    return WorkoutOverview(
      day: data.day,
      exercises: exercises,
      totalSets: exercises.fold(0, (sum, e) => sum + e.config.workingSets),
      plannedVolume: VolumeCalculator.plannedSets([
        for (final e in exercises)
          (muscle: e.primaryMuscle, sets: e.config.workingSets),
      ]),
      isInProgress: data.activeSessionDayId == data.day.id,
      lastCompletedAt: data.lastCompletedAt,
    );
  }
}
