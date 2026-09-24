import '../../../../core/domain/entities/program.dart';
import '../../../../core/result/api_result.dart';
import '../entities/exercise_details.dart';

abstract interface class ExerciseRepository {
  /// Active (not archived) exercises, by name.
  Stream<ApiResult<List<Exercise>>> watchLibrary();

  /// The exercise with resolved media paths and the days using it. The
  /// guide is added by the use case.
  Stream<ApiResult<ExerciseDetails>> watchDetails(String exerciseId);

  Future<ApiResult<Exercise>> getExercise(String exerciseId);

  Future<VoidResult> saveExercise(Exercise exercise);

  /// Hides the exercise and removes it from every plan day.
  Future<VoidResult> archiveExercise(String exerciseId);

  /// Brings an archived exercise back to the library.
  Future<VoidResult> restoreExercise(String exerciseId);
}
