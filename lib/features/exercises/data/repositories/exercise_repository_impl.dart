import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/local_data_sources/program_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/exercise_details.dart';
import '../../domain/repositories/exercise_repository.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  const ExerciseRepositoryImpl(this._programs, this._media);

  final ProgramLocalDataSource _programs;
  final MediaStore _media;

  @override
  Stream<ApiResult<List<Exercise>>> watchLibrary() =>
      guardStream(_programs.watch(_programs.exercises));

  @override
  Stream<ApiResult<ExerciseDetails>> watchDetails(String exerciseId) =>
      guardStream(
        _programs.watch(() {
          final exercise = _programs.requireExercise(exerciseId);
          final image = exercise.imagePath;
          final video = exercise.videoPath;
          return ExerciseDetails(
            exercise: exercise,
            imageFile: image == null ? null : _media.resolve(image),
            videoFile: video == null ? null : _media.resolve(video),
            usedInDays: _programs.daysUsing(exerciseId),
          );
        }),
      );

  @override
  Future<ApiResult<Exercise>> getExercise(String exerciseId) =>
      guardStorage(() => _programs.requireExercise(exerciseId));

  @override
  Future<VoidResult> saveExercise(Exercise exercise) =>
      guardStorage(() => _programs.saveExercise(exercise));

  @override
  Future<VoidResult> archiveExercise(String exerciseId) =>
      guardStorage(() => _programs.archiveExercise(exerciseId));

  @override
  Future<VoidResult> restoreExercise(String exerciseId) =>
      guardStorage(() => _programs.restoreExercise(exerciseId));
}
