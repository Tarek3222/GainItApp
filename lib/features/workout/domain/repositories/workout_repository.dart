import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/result/api_result.dart';
import '../entities/active_workout.dart';
import '../entities/workout_summary.dart';

/// Technology-agnostic contract (spec §24). The MVP implementation is local;
/// a future sync implementation can replace it without touching the UI.
abstract interface class WorkoutRepository {
  Future<ApiResult<WorkoutSession?>> getActiveSession();

  Future<ApiResult<WorkoutSession>> startSession(String workoutDayId);

  Stream<ApiResult<ActiveSessionData>> watchSession(String sessionId);

  Future<VoidResult> saveSet(SetLog set);

  Future<VoidResult> deleteSet(String setId);

  Future<VoidResult> setExerciseSkipped(
    String sessionExerciseId, {
    required bool skipped,
  });

  Future<ApiResult<WorkoutSession>> finishSession(
    String sessionId,
    SessionStatus status,
  );

  Future<ApiResult<WorkoutSummaryData>> getSummaryData(String sessionId);

  Future<ApiResult<AppSettings>> getSettings();
}
