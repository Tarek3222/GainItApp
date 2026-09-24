import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../domain/entities/progress_entities.dart';
import '../../domain/usecases/progress_use_cases.dart';

class ProgressCubit extends StreamViewCubit<ProgressDashboard> {
  ProgressCubit({required this._watchDashboard});

  final WatchProgressDashboardUseCase _watchDashboard;

  @override
  Stream<ApiResult<ProgressDashboard>> source() => _watchDashboard();
}

class ExerciseProgressCubit extends FutureViewCubit<ExerciseProgress> {
  ExerciseProgressCubit({required this.exerciseId, required this._getProgress});

  final String exerciseId;
  final GetExerciseProgressUseCase _getProgress;

  @override
  Future<ApiResult<ExerciseProgress>> fetch() => _getProgress(exerciseId);
}
