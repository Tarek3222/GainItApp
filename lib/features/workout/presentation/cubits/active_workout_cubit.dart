import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/usecases/log_set_use_case.dart';
import '../../domain/usecases/session_actions_use_cases.dart';
import '../../domain/usecases/watch_active_workout_use_case.dart';

part 'active_workout_state.dart';

class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState> {
  ActiveWorkoutCubit({
    required this.sessionId,
    required this._watchWorkout,
    required this._logSet,
    required this._undoSet,
    required this._skipExercise,
    required this._finishWorkout,
    required this._abandonWorkout,
  }) : super(const ActiveWorkoutLoading());

  final String sessionId;
  final WatchActiveWorkoutUseCase _watchWorkout;
  final LogSetUseCase _logSet;
  final UndoSetUseCase _undoSet;
  final SkipExerciseUseCase _skipExercise;
  final FinishWorkoutUseCase _finishWorkout;
  final AbandonWorkoutUseCase _abandonWorkout;

  StreamSubscription<ApiResult<ActiveWorkout>>? _subscription;
  var _messageId = 0;

  void start() {
    _subscription?.cancel();
    emit(const ActiveWorkoutLoading());
    _subscription = _watchWorkout(sessionId).listen(_onData);
  }

  void _onData(ApiResult<ActiveWorkout> result) {
    if (isClosed || state is ActiveWorkoutClosed) return;
    result.fold(
      (failure) => state is ActiveWorkoutLoaded
          ? _showMessage(failure)
          : emit(ActiveWorkoutError(failure.userMessage)),
      (workout) {
        if (!workout.session.isInProgress) {
          emit(
            ActiveWorkoutClosed(
              sessionId: sessionId,
              completed: workout.session.isCompleted,
            ),
          );
          return;
        }
        final current = state;
        emit(
          current is ActiveWorkoutLoaded
              ? current.copyWith(workout: workout)
              : ActiveWorkoutLoaded(workout: workout),
        );
      },
    );
  }

  void _showMessage(Failure failure) {
    if (isClosed) return;
    final current = state;
    if (current is! ActiveWorkoutLoaded) return;
    emit(
      current.copyWith(message: failure.userMessage, messageId: ++_messageId),
    );
  }

  /// Autosaves a set. Returns `true` when it was stored, so the view can
  /// start the rest timer.
  Future<bool> logSet({
    required ActiveExercise exercise,
    required double weight,
    required int reps,
    int? rir,
  }) async {
    final result = await _logSet(
      LogSetInput(
        sessionExerciseId: exercise.snapshot.id,
        setNumber: exercise.nextSetNumber,
        weight: weight,
        reps: reps,
        rir: rir,
        plannedRepsMin: exercise.snapshot.repMin,
        plannedRepsMax: exercise.snapshot.repMax,
        plannedWeight: exercise.recommendation.suggestedWeight,
      ),
    );
    return result.fold((failure) {
      _showMessage(failure);
      return false;
    }, (_) => true);
  }

  Future<void> undoSet(String setId) async {
    final result = await _undoSet(setId);
    if (result case ApiFailure(:final failure)) _showMessage(failure);
  }

  Future<void> setSkipped(ActiveExercise exercise, {required bool skip}) async {
    final result = await _skipExercise(exercise.snapshot.id, skip: skip);
    if (result case ApiFailure(:final failure)) _showMessage(failure);
  }

  Future<void> finish() async {
    final result = await _finishWorkout(sessionId);
    if (isClosed) return;
    result.fold(
      _showMessage,
      (_) => emit(ActiveWorkoutClosed(sessionId: sessionId, completed: true)),
    );
  }

  Future<void> abandon() async {
    final result = await _abandonWorkout(sessionId);
    if (isClosed) return;
    result.fold(
      _showMessage,
      (_) => emit(ActiveWorkoutClosed(sessionId: sessionId, completed: false)),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
