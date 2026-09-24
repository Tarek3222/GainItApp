import '../../../../core/result/api_result.dart';
import '../entities/progress_entities.dart';

abstract interface class ProgressRepository {
  /// All logged sets of completed sessions plus body weights and planned
  /// volume. Date filtering happens in the use case, so the result stays
  /// correct when the week changes while the app is open.
  Stream<ApiResult<ProgressData>> watchProgressData();

  Future<ApiResult<ExerciseHistoryData>> getExerciseHistory(String exerciseId);
}
