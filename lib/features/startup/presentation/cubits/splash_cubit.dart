import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../workout/domain/usecases/session_actions_use_cases.dart';
import '../../domain/entities/startup_status.dart';
import '../../domain/usecases/get_startup_status_use_case.dart';

part 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  SplashCubit({required this._getStatus, required this._abandonWorkout})
    : super(const SplashLoading());

  final GetStartupStatusUseCase _getStatus;
  final AbandonWorkoutUseCase _abandonWorkout;

  Future<void> check() async {
    emit(const SplashLoading());
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
