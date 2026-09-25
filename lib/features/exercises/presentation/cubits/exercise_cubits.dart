import 'package:easy_localization/easy_localization.dart';

import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../domain/entities/exercise_details.dart';
import '../../domain/entities/exercise_input.dart';
import '../../domain/usecases/exercise_use_cases.dart';

class ExerciseLibraryCubit extends StreamViewCubit<List<Exercise>> {
  ExerciseLibraryCubit({required this._watchLibrary});

  final WatchExerciseLibraryUseCase _watchLibrary;

  @override
  Stream<ApiResult<List<Exercise>>> source() => _watchLibrary();
}

class ExerciseDetailsCubit extends StreamViewCubit<ExerciseDetails> {
  ExerciseDetailsCubit({
    required this.exerciseId,
    required this._watchDetails,
    required this._attachMedia,
    required this._removeMedia,
    required this._archive,
    required this._restore,
    this.languageCode = 'en',
  });

  final String exerciseId;

  /// Language of the research guide.
  final String languageCode;
  final WatchExerciseDetailsUseCase _watchDetails;
  final AttachExerciseMediaUseCase _attachMedia;
  final RemoveExerciseMediaUseCase _removeMedia;
  final ArchiveExerciseUseCase _archive;
  final RestoreExerciseUseCase _restore;

  @override
  Stream<ApiResult<ExerciseDetails>> source() =>
      _watchDetails(exerciseId, languageCode: languageCode);

  Future<ActionOutcome<void>> attachMedia(
    ExerciseMediaKind kind,
    MediaSource source,
  ) async => ActionOutcome.from(await _attachMedia(exerciseId, kind, source));

  Future<ActionOutcome<void>> removeImage(String fileName) async =>
      ActionOutcome.from(await _removeMedia.photo(exerciseId, fileName));

  Future<ActionOutcome<void>> removeVideo() async =>
      ActionOutcome.from(await _removeMedia.video(exerciseId));

  Future<ActionOutcome<void>> archive() async =>
      ActionOutcome.from(await _archive(exerciseId));

  Future<ActionOutcome<void>> restore() async =>
      ActionOutcome.from(await _restore(exerciseId));
}

/// Loads the exercise being edited (`null` when creating one) and saves.
class ExerciseEditorCubit extends FutureViewCubit<Exercise?> {
  ExerciseEditorCubit({
    required this.exerciseId,
    required this._getExercise,
    required this._saveExercise,
  });

  /// `null` when creating a new exercise.
  final String? exerciseId;
  final GetExerciseUseCase _getExercise;
  final SaveExerciseUseCase _saveExercise;

  @override
  Future<ApiResult<Exercise?>> fetch() async {
    final id = exerciseId;
    if (id == null) return const ApiSuccess(null);
    return _getExercise(id);
  }

  /// Resolves to the saved exercise's ID.
  Future<ActionOutcome<String>> save(ExerciseInput input) async {
    final current = state;
    // Editing: never fall back to creating a copy if the original hasn't
    // loaded yet.
    if (exerciseId != null && current is! ViewLoaded<Exercise?>) {
      return ActionFailed('common.stillLoading'.tr());
    }
    final existing = current is ViewLoaded<Exercise?> ? current.data : null;
    return ActionOutcome.from(await _saveExercise(input, existing: existing));
  }
}
