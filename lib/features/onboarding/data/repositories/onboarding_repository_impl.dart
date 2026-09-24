import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/local_data_sources/body_weight_local_data_source.dart';
import '../../../../core/storage/local_data_sources/profile_local_data_source.dart';
import '../../../../core/storage/local_data_sources/program_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl(this._profile, this._weights, this._programs);

  final ProfileLocalDataSource _profile;
  final BodyWeightLocalDataSource _weights;
  final ProgramLocalDataSource _programs;

  @override
  Future<VoidResult> completeOnboarding({
    required UserProfile profile,
    required BodyWeightEntry firstWeight,
  }) => guardStorage(() async {
    await _weights.save(firstWeight);
    final program = _programs.activeProgram();
    if (program != null) {
      await _programs.saveProgram(
        program.copyWith(
          startDate: profile.trainingStartDate,
          updatedAt: profile.updatedAt,
        ),
      );
    }
    // Written last: an interrupted onboarding simply runs again.
    await _profile.save(profile);
  });
}
