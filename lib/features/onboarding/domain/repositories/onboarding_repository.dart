import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/result/api_result.dart';

abstract interface class OnboardingRepository {
  /// Stores the first weigh-in, aligns the program start date and saves the
  /// profile last — the profile's existence marks onboarding as complete.
  Future<VoidResult> completeOnboarding({
    required UserProfile profile,
    required BodyWeightEntry firstWeight,
  });
}
