import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/result/api_result.dart';
import '../repositories/workout_repository.dart';

/// Removes a logged set (undo) while the workout is running.
class UndoSetUseCase {
  const UndoSetUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<VoidResult> call(String setId) => _repository.deleteSet(setId);
}

class SkipExerciseUseCase {
  const SkipExerciseUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<VoidResult> call(String sessionExerciseId, {bool skip = true}) =>
      _repository.setExerciseSkipped(sessionExerciseId, skipped: skip);
}

class FinishWorkoutUseCase {
  const FinishWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<ApiResult<WorkoutSession>> call(String sessionId) =>
      _repository.finishSession(sessionId, SessionStatus.completed);
}

/// Abandons (discards) a workout. Logged sets stay in storage, but abandoned
/// sessions never count toward history, volume or progression.
class AbandonWorkoutUseCase {
  const AbandonWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<ApiResult<WorkoutSession>> call(String sessionId) =>
      _repository.finishSession(sessionId, SessionStatus.abandoned);
}
