import '../../../../core/domain/entities/enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/local_data_sources/program_local_data_source.dart';
import '../../../../core/storage/local_data_sources/workout_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/plan_entities.dart';
import '../../domain/repositories/program_repository.dart';

class ProgramRepositoryImpl implements ProgramRepository {
  const ProgramRepositoryImpl(this._programs, this._workouts);

  static const _historyDepth = 5;

  final ProgramLocalDataSource _programs;
  final WorkoutLocalDataSource _workouts;

  List<ChangeTrigger> get _triggers => [
    ..._programs.triggers,
    ..._workouts.triggers,
  ];

  @override
  Stream<ApiResult<WeekPlanData>> watchWeek() =>
      guardStream(watchTriggers(_triggers, _loadWeek));

  WeekPlanData _loadWeek() {
    final program = _programs.requireActiveProgram();
    final days = _programs.days(program.id);
    return WeekPlanData(
      program: program,
      days: days,
      dayExercises: {
        for (final d in days) d.id: _programs.programExercisesForDay(d.id),
      },
      completedSessions: _workouts
          .sessions(status: SessionStatus.completed)
          .where((s) => s.programId == program.id)
          .toList(),
    );
  }

  @override
  Stream<ApiResult<WorkoutDayData>> watchWorkoutDay(String dayId) =>
      guardStream(watchTriggers(_triggers, () => _loadDay(dayId)));

  WorkoutDayData _loadDay(String dayId) {
    final day = _programs.requireDay(dayId);
    final index = _workouts.snapshot();
    final items = [
      for (final config in _programs.programExercisesForDay(dayId))
        (
          config: config,
          exercise:
              _programs.exercise(config.exerciseId) ??
              (throw NotFoundException('Exercise ${config.exerciseId}')),
          history: index.performances(config.exerciseId, limit: _historyDepth),
        ),
    ];
    final completed = _workouts
        .sessions(status: SessionStatus.completed)
        .where((s) => s.workoutDayId == dayId);
    return WorkoutDayData(
      day: day,
      items: items,
      lastCompletedAt: completed.isEmpty
          ? null
          : completed.first.completedAt ?? completed.first.startedAt,
      activeSessionDayId: _workouts.activeSession()?.workoutDayId,
    );
  }
}
