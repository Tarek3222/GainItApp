import '../../../../core/domain/training/workout_session_rules.dart';
import '../../../../core/result/api_result.dart';
import '../entities/startup_status.dart';
import '../repositories/startup_repository.dart';

class GetStartupStatusUseCase {
  const GetStartupStatusUseCase(this._repository);

  final StartupRepository _repository;

  Future<ApiResult<StartupStatus>> call() async {
    final result = await _repository.getStartupData();
    return result.map((data) {
      final session = data.activeSession;
      if (session == null) return StartupStatus(hasProfile: data.hasProfile);
      final progress = WorkoutSessionRules.progress(
        data.activeExercises,
        data.activeSets,
      );
      return StartupStatus(
        hasProfile: data.hasProfile,
        interruptedWorkout: InterruptedWorkout(
          sessionId: session.id,
          workoutName: session.workoutName,
          completedSets: progress.completedSets,
          totalSets: progress.totalSets,
        ),
      );
    });
  }
}
