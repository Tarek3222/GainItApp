import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/domain/utils/combine_results.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/id_generator.dart';
import '../entities/exercise_details.dart';
import '../entities/exercise_guide.dart';
import '../entities/exercise_input.dart';
import '../repositories/exercise_guide_repository.dart';
import '../repositories/exercise_repository.dart';

class WatchExerciseLibraryUseCase {
  const WatchExerciseLibraryUseCase(this._repository);

  final ExerciseRepository _repository;

  Stream<ApiResult<List<Exercise>>> call() => _repository.watchLibrary();
}

/// The exercise with its media, the days using it and its research guide.
class WatchExerciseDetailsUseCase {
  const WatchExerciseDetailsUseCase(this._repository, this._guides);

  final ExerciseRepository _repository;
  final ExerciseGuideRepository _guides;

  Stream<ApiResult<ExerciseDetails>> call(String exerciseId) => combineResults(
    _repository.watchDetails(exerciseId),
    // The guide is extra: if it can't load, the rest of the screen still
    // shows (muscles, media, notes) and flags the guide as unavailable.
    Stream.fromFuture(
      _guides
          .guideFor(exerciseId)
          .then(
            (result) => ApiSuccess<({ExerciseGuide? guide, bool failed})>(
              switch (result) {
                ApiSuccess(:final data) => (guide: data, failed: false),
                ApiFailure() => (guide: null, failed: true),
              },
            ),
          ),
    ),
    (details, g) => details.withGuide(g.guide, unavailable: g.failed),
  );
}

class GetExerciseUseCase {
  const GetExerciseUseCase(this._repository);

  final ExerciseRepository _repository;

  Future<ApiResult<Exercise>> call(String exerciseId) =>
      _repository.getExercise(exerciseId);
}

/// Creates a custom exercise, or updates an existing one from the editor.
class SaveExerciseUseCase {
  const SaveExerciseUseCase(this._repository, this._clock, this._ids);

  final ExerciseRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  /// Returns the saved exercise's ID. [existing] is `null` for a new one.
  Future<ApiResult<String>> call(
    ExerciseInput input, {
    Exercise? existing,
  }) async {
    final instructions = input.instructions?.trim();
    final secondary = [
      for (final m in input.secondaryMuscles)
        if (m != input.primaryMuscle) m,
    ];
    final exercise =
        existing?.copyWith(
          name: input.name.trim(),
          primaryMuscle: input.primaryMuscle,
          secondaryMuscles: secondary,
          category: input.category,
          instructions: instructions,
          clearInstructions: instructions == null || instructions.isEmpty,
        ) ??
        Exercise(
          id: 'ex_custom_${_ids.next()}',
          name: input.name.trim(),
          primaryMuscle: input.primaryMuscle,
          secondaryMuscles: secondary,
          category: input.category,
          isCustom: true,
          createdAt: _clock.now(),
          instructions: instructions == null || instructions.isEmpty
              ? null
              : instructions,
        );
    final errors = Validators.exercise(exercise);
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    final saved = await _repository.saveExercise(exercise);
    return saved.map((_) => exercise.id);
  }
}

class ArchiveExerciseUseCase {
  const ArchiveExerciseUseCase(this._repository);

  final ExerciseRepository _repository;

  Future<VoidResult> call(String exerciseId) =>
      _repository.archiveExercise(exerciseId);
}

/// Undoes [ArchiveExerciseUseCase]: the exercise, with its notes, photo
/// and video, is back in the library and can be added to days again.
class RestoreExerciseUseCase {
  const RestoreExerciseUseCase(this._repository);

  final ExerciseRepository _repository;

  Future<VoidResult> call(String exerciseId) =>
      _repository.restoreExercise(exerciseId);
}

enum ExerciseMediaKind { image, video }

/// Picks a photo or video for an exercise and replaces any previous one.
/// Cancelling the picker changes nothing.
class AttachExerciseMediaUseCase {
  const AttachExerciseMediaUseCase(this._repository, this._media);

  final ExerciseRepository _repository;
  final MediaStore _media;

  Future<VoidResult> call(
    String exerciseId,
    ExerciseMediaKind kind,
    MediaSource source,
  ) async {
    final picked = switch (kind) {
      ExerciseMediaKind.image => await _media.pickImage(source),
      ExerciseMediaKind.video => await _media.pickVideo(source),
    };
    switch (picked) {
      case ApiFailure(:final failure):
        return ApiFailure(failure);
      case ApiSuccess(data: null):
        return voidSuccess;
      case ApiSuccess(:final data?):
        // Re-read after the (slow) picker so a change made meanwhile, e.g.
        // a video added while picking a photo, isn't overwritten.
        final current = await _repository.getExercise(exerciseId);
        if (current case ApiFailure(:final failure)) {
          await _media.delete(data);
          return ApiFailure(failure);
        }
        final exercise = (current as ApiSuccess<Exercise>).data;
        final updated = switch (kind) {
          ExerciseMediaKind.image => exercise.copyWith(imagePath: data),
          ExerciseMediaKind.video => exercise.copyWith(videoPath: data),
        };
        final saved = await _repository.saveExercise(updated);
        if (saved is ApiFailure<void>) {
          await _media.delete(data);
          return saved;
        }
        final previous = switch (kind) {
          ExerciseMediaKind.image => exercise.imagePath,
          ExerciseMediaKind.video => exercise.videoPath,
        };
        if (previous != null && previous != data) {
          await _media.delete(previous);
        }
        return voidSuccess;
    }
  }
}

class RemoveExerciseMediaUseCase {
  const RemoveExerciseMediaUseCase(this._repository, this._media);

  final ExerciseRepository _repository;
  final MediaStore _media;

  Future<VoidResult> call(String exerciseId, ExerciseMediaKind kind) async {
    final current = await _repository.getExercise(exerciseId);
    if (current case ApiFailure(:final failure)) return ApiFailure(failure);
    final exercise = (current as ApiSuccess<Exercise>).data;
    final previous = switch (kind) {
      ExerciseMediaKind.image => exercise.imagePath,
      ExerciseMediaKind.video => exercise.videoPath,
    };
    if (previous == null) return voidSuccess;
    final saved = await _repository.saveExercise(switch (kind) {
      ExerciseMediaKind.image => exercise.copyWith(clearImage: true),
      ExerciseMediaKind.video => exercise.copyWith(clearVideo: true),
    });
    if (saved is ApiSuccess<void>) await _media.delete(previous);
    return saved;
  }
}
