import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';
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
  Stream<ApiResult<WorkoutDayData>> watchWorkoutDay(
    String dayId, {
    bool withHistory = true,
  }) => withHistory
      ? guardStream(watchTriggers(_triggers, () => _loadDay(dayId)))
      // Only plan changes matter here; logging sets doesn't rebuild it.
      : guardStream(
          watchTriggers(_programs.triggers, () => _loadPlanDay(dayId)),
        );

  /// The day and its exercises without scanning workout history.
  WorkoutDayData _loadPlanDay(String dayId) => WorkoutDayData(
    day: _programs.requireDay(dayId),
    items: [
      for (final config in _programs.programExercisesForDay(dayId))
        (
          config: config,
          exercise:
              _programs.exercise(config.exerciseId) ??
              (throw NotFoundException('Exercise ${config.exerciseId}')),
          history: const [],
        ),
    ],
  );

  @override
  Future<ApiResult<WorkoutDay>> getDay(String dayId) =>
      guardStorage(() => _programs.requireDay(dayId));

  @override
  Future<ApiResult<Exercise>> getExercise(String exerciseId) =>
      guardStorage(() => _programs.requireExercise(exerciseId));

  @override
  Future<ApiResult<int>> exerciseCount(String dayId) =>
      guardStorage(() => _programs.programExercisesForDay(dayId).length);

  @override
  Future<VoidResult> saveDay(WorkoutDay day) =>
      guardStorage(() => _programs.saveWorkoutDay(day));

  @override
  Future<VoidResult> saveDayExercise(ProgramExercise entry) =>
      guardStorage(() => _programs.saveProgramExercise(entry));

  @override
  Future<VoidResult> removeDayExercise(String entryId) =>
      guardStorage(() => _programs.removeProgramExercise(entryId));

  @override
  Future<VoidResult> reorderDayExercises(String dayId, List<String> entryIds) =>
      guardStorage(() => _programs.reorderProgramExercises(dayId, entryIds));

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
