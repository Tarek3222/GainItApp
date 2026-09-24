import 'dart:async';

import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../../workout/domain/usecases/start_workout_use_case.dart';
import '../../domain/entities/plan_entities.dart';
import '../../domain/usecases/edit_workout_day_use_cases.dart';
import '../../domain/usecases/watch_weekly_plan_use_case.dart';
import '../../domain/usecases/watch_workout_overview_use_case.dart';

class PlanCubit extends StreamViewCubit<WeeklyPlan> {
  PlanCubit({required this._watchPlan});

  final WatchWeeklyPlanUseCase _watchPlan;

  @override
  Stream<ApiResult<WeeklyPlan>> source() => _watchPlan();
}

class WorkoutOverviewCubit extends StreamViewCubit<WorkoutOverview> {
  WorkoutOverviewCubit({
    required this.dayId,
    required this._watchOverview,
    required this._startWorkout,
  });

  final String dayId;
  final WatchWorkoutOverviewUseCase _watchOverview;
  final StartWorkoutUseCase _startWorkout;

  @override
  Stream<ApiResult<WorkoutOverview>> source() => _watchOverview(dayId);

  /// Resolves to the session ID to open.
  Future<ActionOutcome<String>> startWorkout() async =>
      ActionOutcome.from(await _startWorkout(dayId));
}

/// Edits one plan day: name, workout/rest, and its exercise list.
class WorkoutDayEditorCubit extends StreamViewCubit<WorkoutOverview> {
  WorkoutDayEditorCubit({
    required this.dayId,
    required this._watchDay,
    required this._updateDay,
    required this._addExercise,
    required this._updateConfig,
    required this._removeExercise,
    required this._reorder,
  });

  final String dayId;
  final WatchDayEditorUseCase _watchDay;
  final UpdateWorkoutDayUseCase _updateDay;
  final AddExerciseToDayUseCase _addExercise;
  final UpdateExerciseConfigUseCase _updateConfig;
  final RemoveExerciseFromDayUseCase _removeExercise;
  final ReorderDayExercisesUseCase _reorder;

  @override
  Stream<ApiResult<WorkoutOverview>> source() => _watchDay(dayId);

  Future<ActionOutcome<void>> rename(String name) async =>
      ActionOutcome.from(await _updateDay(dayId, name: name));

  Future<ActionOutcome<void>> setType(DayType type) async =>
      ActionOutcome.from(await _updateDay(dayId, type: type));

  Future<ActionOutcome<void>> addExercise(String exerciseId) async =>
      ActionOutcome.from(await _addExercise(dayId, exerciseId));

  Future<ActionOutcome<void>> updateConfig(ProgramExercise entry) async =>
      ActionOutcome.from(await _updateConfig(entry));

  Future<ActionOutcome<void>> removeExercise(String entryId) async =>
      ActionOutcome.from(await _removeExercise(entryId));

  Future<void> _moves = Future.value();

  /// Moves the entry at [oldIndex] to [newIndex] (list positions after the
  /// move, as reported by the reorderable list). The new order shows at
  /// once; moves run one after another so a quick second drag never works
  /// on an outdated list.
  Future<ActionOutcome<void>> move(int oldIndex, int newIndex) {
    final done = Completer<ActionOutcome<void>>();
    _moves = _moves.then(
      (_) async => done.complete(await _move(oldIndex, newIndex)),
    );
    return done.future;
  }

  Future<ActionOutcome<void>> _move(int oldIndex, int newIndex) async {
    final current = state;
    if (current is! ViewLoaded<WorkoutOverview>) {
      return const ActionFailed('Still loading.');
    }
    final exercises = [...current.data.exercises];
    if (oldIndex < 0 || oldIndex >= exercises.length) {
      return const ActionDone(null);
    }
    final moved = exercises.removeAt(oldIndex);
    exercises.insert(newIndex.clamp(0, exercises.length), moved);
    if (!isClosed) emit(ViewLoaded(current.data.withExercises(exercises)));
    final result = await _reorder(dayId, [
      for (final e in exercises) e.config.id,
    ]);
    // Storage didn't change, so no update will come: restore the old order.
    if (result is ApiFailure<void> && !isClosed) emit(current);
    return ActionOutcome.from(result);
  }
}
