import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../../core/services/clock.dart';
import '../../domain/entities/onboarding_input.dart';
import '../../domain/usecases/complete_onboarding_use_case.dart';

part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required this._completeOnboarding, required this._clock})
    : super(const OnboardingIdle());

  final CompleteOnboardingUseCase _completeOnboarding;
  final Clock _clock;

  /// Default training start date shown in the form.
  DateTime get today => _clock.now();

  Future<void> submit(OnboardingInput input) async {
    if (state is OnboardingSubmitting) return;
    emit(const OnboardingSubmitting());
    final result = await _completeOnboarding(input);
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => OnboardingFailure(failure.userMessage),
        (_) => const OnboardingSuccess(),
      ),
    );
  }
}
