import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/id_generator.dart';
import '../entities/onboarding_input.dart';
import '../repositories/onboarding_repository.dart';

class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._repository, this._clock, this._ids);

  /// Fixed ID for the onboarding weigh-in. If onboarding is interrupted after
  /// the weight is saved but before the profile, the retry overwrites that
  /// entry instead of adding a duplicate.
  static const firstWeighInId = 'onboarding-first-weigh-in';

  final OnboardingRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  Future<VoidResult> call(OnboardingInput input) async {
    final now = _clock.now();
    final start = input.trainingStartDate;
    final profile = UserProfile(
      id: _ids.next(),
      name: input.name.trim(),
      heightCm: input.heightCm,
      goal: input.goal,
      trainingStartDate: DateTime(start.year, start.month, start.day),
      unitSystem: input.unitSystem,
      birthDate: UserProfile.birthDateFor(input.age, now),
      createdAt: now,
      updatedAt: now,
    );
    final weight = BodyWeightEntry(
      id: firstWeighInId,
      weightKg: input.weightKg,
      measuredAt: now,
    );
    final errors = [
      ...Validators.profile(profile),
      ...Validators.age(input.age),
      ...Validators.bodyWeight(weight),
    ];
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    return _repository.completeOnboarding(
      profile: profile,
      firstWeight: weight,
    );
  }
}
