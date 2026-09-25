import '../../../../core/result/api_result.dart';
import '../entities/exercise_guide.dart';

abstract interface class ExerciseGuideRepository {
  /// The bundled guide for [exerciseId] in [languageCode] (English when
  /// that language has none), or `null` when there is none at all (e.g. a
  /// custom exercise).
  Future<ApiResult<ExerciseGuide?>> guideFor(
    String exerciseId, {
    String languageCode = 'en',
  });
}
