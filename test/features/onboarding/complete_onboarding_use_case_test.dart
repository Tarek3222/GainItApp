import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/body_weight_entry.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/user_profile.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/features/onboarding/domain/entities/onboarding_input.dart';
import 'package:gainit/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:gainit/features/onboarding/domain/usecases/complete_onboarding_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixed_clock.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository {}

void main() {
  late _MockOnboardingRepository repository;
  late CompleteOnboardingUseCase useCase;

  OnboardingInput input({int age = 30, UnitSystem units = UnitSystem.metric}) =>
      OnboardingInput(
        name: 'Sam',
        heightCm: 180,
        weightKg: 80,
        age: age,
        goal: TrainingGoal.gainMuscle,
        trainingStartDate: DateTime(2026, 3, 1),
        unitSystem: units,
      );

  setUp(() {
    repository = _MockOnboardingRepository();
    useCase = CompleteOnboardingUseCase(
      repository,
      FixedClock(DateTime(2026, 3, 1)),
      const IdGenerator(),
    );
    when(
      () => repository.completeOnboarding(
        profile: any(named: 'profile'),
        firstWeight: any(named: 'firstWeight'),
      ),
    ).thenAnswer((_) async => voidSuccess);
  });

  setUpAll(() {
    registerFallbackValue(
      UserProfile(
        id: '',
        name: '',
        heightCm: 0,
        goal: TrainingGoal.maintain,
        trainingStartDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    registerFallbackValue(
      BodyWeightEntry(id: '', weightKg: 0, measuredAt: DateTime(2026)),
    );
  });

  test('stores the birth year and chosen units on the profile', () async {
    final result = await useCase(input(age: 30, units: UnitSystem.imperial));

    expect(result.isSuccess, isTrue);
    final profile =
        verify(
              () => repository.completeOnboarding(
                profile: captureAny(named: 'profile'),
                firstWeight: any(named: 'firstWeight'),
              ),
            ).captured.single
            as UserProfile;
    expect(profile.birthDate, DateTime(1996, 3, 1));
    expect(profile.ageOn(DateTime(2026, 3, 1)), 30);
    expect(profile.unitSystem, UnitSystem.imperial);
  });

  test('rejects an age outside 13–90 without saving', () async {
    final result = await useCase(input(age: 10));

    expect(
      (result as ApiFailure<void>).failure,
      isA<ValidationFailure>().having(
        (f) => f.errors,
        'errors',
        contains('Age must be between 13 and 90.'),
      ),
    );
    verifyNever(
      () => repository.completeOnboarding(
        profile: any(named: 'profile'),
        firstWeight: any(named: 'firstWeight'),
      ),
    );
  });
}
