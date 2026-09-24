import '../../../../core/domain/services/day_change_source.dart';
import '../../../../core/domain/training/schedule_resolver.dart';
import '../../../../core/domain/utils/rebuild_on.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/services/clock.dart';
import '../entities/plan_entities.dart';
import '../repositories/program_repository.dart';

class WatchWeeklyPlanUseCase {
  const WatchWeeklyPlanUseCase(this._repository, this._clock, this._dayChanges);

  final ProgramRepository _repository;
  final Clock _clock;
  final DayChangeSource _dayChanges;

  Stream<ApiResult<WeeklyPlan>> call() =>
      rebuildOn(_repository.watchWeek(), _dayChanges.changes, build);

  WeeklyPlan build(WeekPlanData data) {
    final today = _clock.now();
    final weekStart = ScheduleResolver.weekStart(today);
    final weekEnd = ScheduleResolver.weekEnd(today);
    final completedThisWeek = <String>{};
    final lastCompleted = <String, DateTime>{};
    for (final session in data.completedSessions) {
      final at = session.completedAt ?? session.startedAt;
      final previous = lastCompleted[session.workoutDayId];
      if (previous == null || at.isAfter(previous)) {
        lastCompleted[session.workoutDayId] = at;
      }
      if (!at.isBefore(weekStart) && at.isBefore(weekEnd)) {
        completedThisWeek.add(session.workoutDayId);
      }
    }

    final days = [
      for (final day in ScheduleResolver.ordered(data.days))
        PlanDay(
          day: day,
          status: ScheduleResolver.statusOf(
            day: day,
            today: today,
            completedDayIdsThisWeek: completedThisWeek,
            programStart: data.program.startDate,
          ),
          date: ScheduleResolver.dateInWeekOf(day, today),
          exerciseCount: data.dayExercises[day.id]?.length ?? 0,
          totalSets: (data.dayExercises[day.id] ?? const []).fold(
            0,
            (sum, e) => sum + e.workingSets,
          ),
          lastCompletedAt: lastCompleted[day.id],
        ),
    ];
    final workoutDays = days.where((d) => d.day.isWorkout);
    return WeeklyPlan(
      programName: data.program.name,
      weekNumber: ScheduleResolver.weekNumber(data.program.startDate, today),
      days: days,
      completedWorkouts: workoutDays
          .where((d) => completedThisWeek.contains(d.day.id))
          .length,
      plannedWorkouts: workoutDays.length,
    );
  }
}
