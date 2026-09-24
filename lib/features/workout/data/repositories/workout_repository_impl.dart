import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/id_generator.dart';
import '../../../../core/storage/local_data_sources/settings_local_data_source.dart';
import '../../../../core/storage/local_data_sources/workout_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/workout_summary.dart';
import '../../domain/repositories/workout_repository.dart';

/// Local (Hive) implementation. A future `SyncWorkoutRepository` can wrap
/// this and a remote source behind the same interface.
class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl(
    this._workouts,
    this._settings,
    this._clock,
    this._ids,
  );

  static const _historyDepth = 5;

  final WorkoutLocalDataSource _workouts;
  final SettingsLocalDataSource _settings;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Future<ApiResult<WorkoutSession?>> getActiveSession() =>
      guardStorage(_workouts.activeSession);

  @override
  Future<ApiResult<WorkoutSession>> startSession(String workoutDayId) =>
      guardStorage(
        () => _workouts.startSession(
          dayId: workoutDayId,
          now: _clock.now(),
          newId: _ids.next,
        ),
      );

  @override
  Stream<ApiResult<ActiveSessionData>> watchSession(String sessionId) =>
      guardStream(_workouts.watch(() => _loadSession(sessionId)));

  ActiveSessionData _loadSession(String sessionId) {
    final index = _workouts.snapshot();
    final session =
        index.session(sessionId) ??
        (throw NotFoundException('Workout $sessionId not found.'));
    final exercises = index.exercisesOf(sessionId);
    return ActiveSessionData(
      session: session,
      exercises: exercises,
      sets: index.setsOf(sessionId),
      history: {
        for (final e in exercises)
          e.exerciseId: index.performances(
            e.exerciseId,
            excludeSessionId: sessionId,
            limit: _historyDepth,
          ),
      },
    );
  }

  @override
  Future<VoidResult> saveSet(SetLog set) =>
      guardStorage(() => _workouts.saveSet(set));

  @override
  Future<VoidResult> deleteSet(String setId) =>
      guardStorage(() => _workouts.deleteSet(setId));

  @override
  Future<VoidResult> setExerciseSkipped(
    String sessionExerciseId, {
    required bool skipped,
  }) => guardStorage(
    () => _workouts.setSkipped(sessionExerciseId, skipped: skipped),
  );

  @override
  Future<ApiResult<WorkoutSession>> finishSession(
    String sessionId,
    SessionStatus status,
  ) => guardStorage(
    () => _workouts.finish(sessionId, status: status, at: _clock.now()),
  );

  @override
  Future<ApiResult<WorkoutSummaryData>> getSummaryData(String sessionId) =>
      guardStorage(() {
        final index = _workouts.snapshot();
        final session =
            index.session(sessionId) ??
            (throw NotFoundException('Workout $sessionId not found.'));
        final exercises = index.exercisesOf(sessionId);
        final previous = <String, ExerciseSessionPerformance>{};
        for (final e in exercises) {
          // Only sessions before this one count as "previous" (matters when
          // re-opening an old summary from history).
          final before = index
              .performances(e.exerciseId, excludeSessionId: sessionId)
              .where((h) => h.date.isBefore(session.startedAt));
          if (before.isNotEmpty) previous[e.exerciseId] = before.first;
        }
        return WorkoutSummaryData(
          session: session,
          exercises: exercises,
          sets: index.setsOf(sessionId),
          previous: previous,
        );
      });

  @override
  Future<ApiResult<AppSettings>> getSettings() =>
      guardStorage(_settings.settings);
}
