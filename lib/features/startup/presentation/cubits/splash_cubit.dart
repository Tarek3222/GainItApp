import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../../core/result/api_result.dart';
import '../../../daily_goals/domain/usecases/daily_goal_use_cases.dart';
import '../../../settings/domain/usecases/settings_use_cases.dart';
import '../../../workout/domain/usecases/session_actions_use_cases.dart';
import '../../domain/entities/startup_status.dart';
import '../../domain/usecases/get_startup_status_use_case.dart';

part 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  SplashCubit({
    required this._getStatus,
    required this._abandonWorkout,
    required this._syncReminders,
    required this._syncWorkoutReminders,
  }) : super(const SplashLoading());

  final GetStartupStatusUseCase _getStatus;
  final AbandonWorkoutUseCase _abandonWorkout;
  final SyncGoalRemindersUseCase _syncReminders;
  final SyncWorkoutRemindersUseCase _syncWorkoutReminders;

  Future<void> check() async {
    emit(const SplashLoading());
    // Reminders are refreshed on every launch: goal reminders skip goals
    // already reached today, and both follow a changed phone language. It
    // runs here rather than in `main` so the translations used for their
    // texts are loaded. Never blocks startup; nothing to show on failure.
    unawaited(_syncReminders().then(_logFailure));
    unawaited(_syncWorkoutReminders().then(_logFailure));
    final result = await _getStatus();
    if (isClosed) return;
    emit(
      result.fold((failure) => SplashError(failure.userMessage), (status) {
        if (!status.hasProfile) return const SplashNeedsOnboarding();
        final interrupted = status.interruptedWorkout;
        return interrupted == null
            ? const SplashReady()
            : SplashInterruptedWorkout(interrupted);
      }),
    );
  }

  static void _logFailure(VoidResult result) {
    if (result case ApiFailure(:final failure) when kDebugMode) {
      debugPrint('Reminder refresh failed: ${failure.runtimeType}');
    }
  }

  Future<void> discard(String sessionId) async {
    final result = await _abandonWorkout(sessionId);
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => SplashError(failure.userMessage),
        (_) => const SplashReady(),
      ),
    );
  }
}
