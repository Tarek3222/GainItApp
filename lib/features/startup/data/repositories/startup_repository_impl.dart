import '../../../../core/result/api_result.dart';
import '../../../../core/storage/local_data_sources/profile_local_data_source.dart';
import '../../../../core/storage/local_data_sources/workout_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/startup_status.dart';
import '../../domain/repositories/startup_repository.dart';

class StartupRepositoryImpl implements StartupRepository {
  const StartupRepositoryImpl(this._profile, this._workouts);

  final ProfileLocalDataSource _profile;
  final WorkoutLocalDataSource _workouts;

  @override
  Future<ApiResult<StartupData>> getStartupData() => guardStorage(() {
    final active = _workouts.activeSession();
    return StartupData(
      hasProfile: _profile.profile() != null,
      activeSession: active,
      activeExercises: active == null
          ? const []
          : _workouts.exercisesOf(active.id),
      activeSets: active == null ? const [] : _workouts.setsOf(active.id),
    );
  });
}
