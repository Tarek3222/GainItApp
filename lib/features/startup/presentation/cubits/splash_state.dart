part of 'splash_cubit.dart';

sealed class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

final class SplashLoading extends SplashState {
  const SplashLoading();
}

final class SplashNeedsOnboarding extends SplashState {
  const SplashNeedsOnboarding();
}

final class SplashReady extends SplashState {
  const SplashReady();
}

/// The app was closed mid-workout: offer Resume / Discard (spec §20).
final class SplashInterruptedWorkout extends SplashState {
  const SplashInterruptedWorkout(this.workout);

  final InterruptedWorkout workout;

  @override
  List<Object?> get props => [workout];
}

final class SplashError extends SplashState {
  const SplashError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
