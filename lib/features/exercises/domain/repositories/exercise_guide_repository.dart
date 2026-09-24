import '../../../../core/result/api_result.dart';
import '../entities/exercise_guide.dart';

abstract interface class ExerciseGuideRepository {
  /// The bundled guide for [exerciseId], or `null` when there is none
  /// (e.g. a custom exercise).
  Future<ApiResult<ExerciseGuide?>> guideFor(String exerciseId);
}
