part of 'onboarding_cubit.dart';

sealed class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

final class OnboardingIdle extends OnboardingState {
  const OnboardingIdle();
}

final class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting();
}

final class OnboardingSuccess extends OnboardingState {
  const OnboardingSuccess();
}

final class OnboardingFailure extends OnboardingState {
  const OnboardingFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
