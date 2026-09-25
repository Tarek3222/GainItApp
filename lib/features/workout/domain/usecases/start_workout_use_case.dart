import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../repositories/workout_repository.dart';

/// Starts the given day's workout, or resumes it when it is already running.
/// Returns the session ID.
class StartWorkoutUseCase {
  const StartWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<ApiResult<String>> call(String workoutDayId) async {
    final active = await _repository.getActiveSession();
    switch (active) {
      case ApiFailure(:final failure):
        return ApiFailure(failure);
      case ApiSuccess(data: final session?):
        if (session.workoutDayId == workoutDayId) return ApiSuccess(session.id);
        return ApiFailure(
          InvalidStateFailure(
            'errors.finishOtherWorkout',
            args: {'name': session.workoutName},
          ),
        );
      case ApiSuccess():
        final started = await _repository.startSession(workoutDayId);
        return started.map((session) => session.id);
    }
  }
}
