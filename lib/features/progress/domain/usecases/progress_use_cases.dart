import '../../../../core/domain/services/day_change_source.dart';
import '../../../../core/domain/training/body_weight_trend.dart';
import '../../../../core/domain/training/one_rep_max.dart';
import '../../../../core/domain/training/schedule_resolver.dart';
import '../../../../core/domain/training/volume_calculator.dart';
import '../../../../core/domain/utils/rebuild_on.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/services/clock.dart';
import '../entities/progress_entities.dart';
import '../repositories/progress_repository.dart';

class WatchProgressDashboardUseCase {
  const WatchProgressDashboardUseCase(
    this._repository,
    this._clock,
    this._dayChanges,
  );

  final ProgressRepository _repository;
  final Clock _clock;
  final DayChangeSource _dayChanges;

  Stream<ApiResult<ProgressDashboard>> call() =>
      rebuildOn(_repository.watchProgressData(), _dayChanges.changes, build);

  ProgressDashboard build(ProgressData data) {
    final now = _clock.now();
    final done = VolumeCalculator.directSets(
      data.loggedSets,
      from: ScheduleResolver.weekStart(now),
      to: ScheduleResolver.weekEnd(now),
    );
    final planned = VolumeCalculator.plannedSets(data.plannedConfig);
    final muscles = {...planned.keys, ...done.keys}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final ascending = BodyWeightTrend.sortedAscending(data.weights);
    return ProgressDashboard(
      weightPoints: [
        for (final e in ascending) WeightPoint(e.measuredAt, e.weightKg),
      ],
      weightTrend: BodyWeightTrend.rollingAverage(ascending),
      bodyWeight: BodyWeightTrend.summary(ascending),
      weeklyVolume: [
        for (final m in muscles)
          MuscleVolume(muscle: m, done: done[m] ?? 0, planned: planned[m] ?? 0),
      ],
      exercises: data.exercisesWithHistory,
    );
  }
}

class GetExerciseProgressUseCase {
  const GetExerciseProgressUseCase(this._repository);

  final ProgressRepository _repository;

  Future<ApiResult<ExerciseProgress>> call(String exerciseId) async {
    final result = await _repository.getExerciseHistory(exerciseId);
    return result.map(build);
  }

  static ExerciseProgress build(ExerciseHistoryData data) {
    final sessions = data.sessions.where((s) => !s.isEmpty).toList();
    if (sessions.isEmpty) {
      return ExerciseProgress(
        exercise: data.exercise,
        sessions: const [],
        trend: const [],
      );
    }
    double bestWeight = 0;
    int bestReps = 0;
    double bestOneRepMax = 0;
    for (final session in sessions) {
      for (final set in session.sets) {
        if (set.weight > bestWeight) bestWeight = set.weight;
        if (set.reps > bestReps) bestReps = set.reps;
        final e1rm = OneRepMax.epley(set.weight, set.reps);
        if (e1rm > bestOneRepMax) bestOneRepMax = e1rm;
      }
    }
    return ExerciseProgress(
      exercise: data.exercise,
      bestWeight: bestWeight,
      bestReps: bestReps,
      bestOneRepMax: bestOneRepMax,
      sessions: sessions,
      trend: [
        for (final s in sessions.reversed)
          ExerciseTrendPoint(
            date: s.date,
            topWeight: s.topWeight,
            totalReps: s.totalReps,
            volumeLoad: s.volumeLoad,
            estimatedOneRepMax: s.sets
                .map((set) => OneRepMax.epley(set.weight, set.reps))
                .reduce((a, b) => a > b ? a : b),
          ),
      ],
    );
  }
}
