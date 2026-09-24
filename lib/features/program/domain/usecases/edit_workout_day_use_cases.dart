import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/id_generator.dart';
import '../entities/plan_entities.dart';
import '../repositories/program_repository.dart';
import 'watch_workout_overview_use_case.dart';

/// The day being edited: its exercises and target muscles, without the
/// history scan and progression targets the workout preview needs.
class WatchDayEditorUseCase {
  const WatchDayEditorUseCase(this._repository);

  final ProgramRepository _repository;

  Stream<ApiResult<WorkoutOverview>> call(String dayId) {
    final builder = WatchWorkoutOverviewUseCase(_repository);
    return _repository
        .watchWorkoutDay(dayId, withHistory: false)
        .map((result) => result.map(builder.build));
  }
}

/// Renames a day or switches it between workout and rest.
class UpdateWorkoutDayUseCase {
  const UpdateWorkoutDayUseCase(this._repository);

  final ProgramRepository _repository;

  Future<VoidResult> call(String dayId, {String? name, DayType? type}) async {
    final current = await _repository.getDay(dayId);
    switch (current) {
      case ApiFailure(:final failure):
        return ApiFailure(failure);
      case ApiSuccess(data: final day):
        final updated = day.copyWith(name: name?.trim(), type: type);
        final errors = Validators.workoutDay(updated);
        if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
        return _repository.saveDay(updated);
    }
  }
}

/// Appends an exercise to a day with sensible defaults for its category:
/// compounds 3 × 6–10 with 2–3 min rest, isolations 3 × 10–15 with
/// 60–90 s rest, weights in 1 kg steps.
class AddExerciseToDayUseCase {
  const AddExerciseToDayUseCase(this._repository, this._ids);

  final ProgramRepository _repository;
  final IdGenerator _ids;

  Future<VoidResult> call(String dayId, String exerciseId) async {
    final exercise = await _repository.getExercise(exerciseId);
    final count = await _repository.exerciseCount(dayId);
    switch ((exercise, count)) {
      case (ApiFailure(:final failure), _):
        return ApiFailure(failure);
      case (_, ApiFailure(:final failure)):
        return ApiFailure(failure);
      case (ApiSuccess(data: final e), ApiSuccess(data: final index)):
        final compound = e.category == ExerciseCategory.compound;
        return _repository.saveDayExercise(
          ProgramExercise(
            id: 'pe_custom_${_ids.next()}',
            workoutDayId: dayId,
            exerciseId: exerciseId,
            orderIndex: index,
            workingSets: 3,
            repMin: compound ? 6 : 10,
            repMax: compound ? 10 : 15,
            restMinSeconds: compound ? 120 : 60,
            restMaxSeconds: compound ? 180 : 90,
            rirMin: compound ? 1 : 0,
            rirMax: compound ? 3 : 2,
            weightStep: 1,
          ),
        );
    }
  }
}

/// Saves the edited sets, reps, rest, RIR, weight step, superset and notes.
class UpdateExerciseConfigUseCase {
  const UpdateExerciseConfigUseCase(this._repository);

  final ProgramRepository _repository;

  Future<VoidResult> call(ProgramExercise entry) async {
    final errors = Validators.programExercise(entry);
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    return _repository.saveDayExercise(entry);
  }
}

class RemoveExerciseFromDayUseCase {
  const RemoveExerciseFromDayUseCase(this._repository);

  final ProgramRepository _repository;

  Future<VoidResult> call(String entryId) =>
      _repository.removeDayExercise(entryId);
}

class ReorderDayExercisesUseCase {
  const ReorderDayExercisesUseCase(this._repository);

  final ProgramRepository _repository;

  Future<VoidResult> call(String dayId, List<String> entryIds) =>
      _repository.reorderDayExercises(dayId, entryIds);
}
