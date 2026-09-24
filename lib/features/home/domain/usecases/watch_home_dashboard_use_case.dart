import '../../../../core/domain/services/day_change_source.dart';
import '../../../../core/domain/training/body_weight_trend.dart';
import '../../../../core/domain/training/performance_comparator.dart';
import '../../../../core/domain/training/schedule_resolver.dart';
import '../../../../core/domain/utils/rebuild_on.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/services/clock.dart';
import '../entities/home_dashboard.dart';
import '../repositories/home_repository.dart';

/// Answers the four dashboard questions (spec §4.B): next workout, last
/// performance, body-weight trend, and whether the user is progressing.
class WatchHomeDashboardUseCase {
  const WatchHomeDashboardUseCase(
    this._repository,
    this._clock,
    this._dayChanges,
  );

  final HomeRepository _repository;
  final Clock _clock;
  final DayChangeSource _dayChanges;

  Stream<ApiResult<HomeDashboard>> call() =>
      rebuildOn(_repository.watchHomeData(), _dayChanges.changes, build);

  HomeDashboard build(HomeData data) {
    final now = _clock.now();
    final weekStart = ScheduleResolver.weekStart(now);
    final weekEnd = ScheduleResolver.weekEnd(now);
    final thisWeek = data.completedSessions.where((s) {
      final at = s.completedAt ?? s.startedAt;
      return !at.isBefore(weekStart) && at.isBefore(weekEnd);
    }).toList();
    final completedDayIds = thisWeek.map((s) => s.workoutDayId).toSet();

    final next = ScheduleResolver.nextWorkout(
      days: data.days,
      today: now,
      completedDayIdsThisWeek: completedDayIds,
    );
    final workoutDayIds = data.days
        .where((d) => d.isWorkout)
        .map((d) => d.id)
        .toSet();

    return HomeDashboard(
      greeting: greetingFor(now),
      name: data.profile?.name ?? '',
      weekNumber: ScheduleResolver.weekNumber(data.program.startDate, now),
      programName: data.program.name,
      nextWorkout: next == null
          ? null
          : NextWorkoutInfo(
              dayId: next.day.id,
              name: next.day.name,
              date: next.date,
              isToday: next.isToday,
              exerciseCount: data.exerciseCountPerDay[next.day.id] ?? 0,
              totalSets: data.plannedSetsPerDay[next.day.id] ?? 0,
            ),
      activeSessionId: data.activeSession?.id,
      activeWorkoutName: data.activeSession?.workoutName,
      bodyWeight: BodyWeightTrend.summary(data.weights),
      weekCompletedWorkouts: completedDayIds
          .where(workoutDayIds.contains)
          .length,
      weekPlannedWorkouts: workoutDayIds.length,
      weekWorkingSets: thisWeek.fold(
        0,
        (sum, s) => sum + (data.workingSetsPerSession[s.id] ?? 0),
      ),
      lastProgress: _lastProgress(data),
    );
  }

  /// The most notable result of the last workout: the first improvement,
  /// otherwise the first exercise.
  HomeProgress? _lastProgress(HomeData data) {
    HomeProgress? first;
    for (final pair in data.lastSessionExercises) {
      final progress = HomeProgress(
        exerciseId: pair.exerciseId,
        exerciseName: pair.name,
        current: pair.current,
        previous: pair.previous,
        comparison: PerformanceComparator.compare(
          current: pair.current,
          previous: pair.previous,
        ),
      );
      if (progress.comparison.isImprovement) return progress;
      first ??= progress;
    }
    return first;
  }

  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
