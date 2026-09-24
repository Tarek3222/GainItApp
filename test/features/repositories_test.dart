import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/core/storage/local_data_sources/body_weight_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/profile_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/program_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/settings_local_data_source.dart';
import 'package:gainit/core/storage/migrations/storage_migrator.dart';
import 'package:gainit/core/storage/storage_bootstrap.dart';
import 'package:gainit/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:gainit/features/onboarding/domain/entities/onboarding_input.dart';
import 'package:gainit/features/onboarding/domain/usecases/complete_onboarding_use_case.dart';
import 'package:gainit/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:gainit/features/settings/domain/usecases/settings_use_cases.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixed_clock.dart';
import '../helpers/hive_test_harness.dart';

class _MockScheduler extends Mock implements NotificationScheduler {}

void main() {
  final harness = HiveTestHarness();
  final clock = FixedClock(DateTime(2026, 3, 1, 18));
  late ProgramLocalDataSource programs;
  late ProfileLocalDataSource profile;
  late BodyWeightLocalDataSource weights;
  late SettingsLocalDataSource settings;

  final input = OnboardingInput(
    name: 'Tarek',
    heightCm: 178,
    weightKg: 72.4,
    goal: TrainingGoal.gainMuscle,
    trainingStartDate: DateTime(2026, 3, 1),
  );

  setUp(() async {
    await harness.setUp();
    await StorageBootstrap.run(harness.storage, now: clock.now());
    programs = ProgramLocalDataSource(harness.storage);
    profile = ProfileLocalDataSource(harness.storage);
    weights = BodyWeightLocalDataSource(harness.storage);
    settings = SettingsLocalDataSource(harness.storage);
  });
  tearDown(harness.tearDown);

  CompleteOnboardingUseCase onboarding() => CompleteOnboardingUseCase(
    OnboardingRepositoryImpl(profile, weights, programs),
    clock,
    const IdGenerator(),
  );

  test('re-running onboarding does not duplicate the first weigh-in', () async {
    // First attempt "interrupted": the weigh-in was stored, the profile wasn't.
    await onboarding()(input);
    await harness.storage.profile.clear();

    await onboarding()(input);

    expect(weights.entries(), hasLength(1));
    expect(profile.profile()!.name, 'Tarek');
  });

  group('delete all data', () {
    late _MockScheduler scheduler;

    setUp(() {
      scheduler = _MockScheduler();
      when(() => scheduler.cancelWorkoutReminders()).thenAnswer((_) async {});
      when(() => scheduler.cancelRestOver()).thenAnswer((_) async {});
    });

    test(
      'wipes user data, re-seeds the program and stamps the schema',
      () async {
        await onboarding()(input);
        final useCase = DeleteAllDataUseCase(
          SettingsRepositoryImpl(
            harness.storage,
            settings,
            profile,
            programs,
            clock,
          ),
          scheduler,
        );

        final result = await useCase();

        expect(result.isSuccess, isTrue);
        expect(profile.profile(), isNull);
        expect(weights.entries(), isEmpty);
        expect(programs.activeProgram(), isNotNull);
        expect(harness.storage.programExercises.length, 27);
        expect(settings.schemaVersion(), StorageMigrator.latestVersion);
        verify(() => scheduler.cancelWorkoutReminders()).called(1);
        verify(() => scheduler.cancelRestOver()).called(1);
      },
    );
  });
}
