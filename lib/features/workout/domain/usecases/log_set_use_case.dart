import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/id_generator.dart';
import '../entities/active_workout.dart';
import '../repositories/workout_repository.dart';

/// Validates and immediately persists one completed set (autosave).
class LogSetUseCase {
  const LogSetUseCase(this._repository, this._clock, this._ids);

  final WorkoutRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  Future<VoidResult> call(LogSetInput input) async {
    final set = SetLog(
      id: _ids.next(),
      sessionExerciseId: input.sessionExerciseId,
      setNumber: input.setNumber,
      plannedRepsMin: input.plannedRepsMin,
      plannedRepsMax: input.plannedRepsMax,
      plannedWeight: input.plannedWeight,
      actualWeight: input.weight,
      actualReps: input.reps,
      rir: input.rir,
      completedAt: _clock.now(),
    );
    final errors = Validators.setLog(set);
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    return _repository.saveSet(set);
  }
}
