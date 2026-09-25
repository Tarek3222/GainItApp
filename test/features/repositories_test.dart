import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
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
import 'package:gainit/features/settings/domain/entities/settings_overview.dart';
import 'package:gainit/features/settings/domain/usecases/settings_use_cases.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_media_store.dart';
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
    age: 30,
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

  test('the settings overview resolves the stored photo name', () async {
    await onboarding()(input);
    final me = profile.profile()!;
    await profile.save(me.copyWith(photoPath: 'me.jpg'));
    final media = FakeMediaStore(files: {'me.jpg'});
    final repository = SettingsRepositoryImpl(
      harness.storage,
      settings,
      profile,
      programs,
      clock,
      media,
    );

    final overview = await repository.watchOverview().first;

    expect(
      (overview as ApiSuccess<SettingsOverview>).data.photoFile,
      '/media/me.jpg',
    );
  });

  group('delete all data', () {
    late _MockScheduler scheduler;
    late FakeMediaStore media;

    setUp(() {
      scheduler = _MockScheduler();
      media = FakeMediaStore();
      when(() => scheduler.cancelWorkoutReminders()).thenAnswer((_) async {});
      when(() => scheduler.cancelRestOver()).thenAnswer((_) async {});
      when(() => scheduler.cancelGoalReminders()).thenAnswer((_) async {});
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
            media,
          ),
          scheduler,
          media,
        );

        final result = await useCase();

        expect(result.isSuccess, isTrue);
        expect(profile.profile(), isNull);
        expect(weights.entries(), isEmpty);
        expect(programs.activeProgram(), isNotNull);
        expect(harness.storage.programExercises.length, 27);
        expect(settings.schemaVersion(), StorageMigrator.latestVersion);
        verify(() => scheduler.cancelWorkoutReminders()).called(1);
        verify(() => scheduler.cancelGoalReminders()).called(1);
        verify(() => scheduler.cancelRestOver()).called(1);
        expect(media.clearAllCalls, 1);
      },
    );

    test(
      'a media cleanup failure still resets and cancels reminders',
      () async {
        await onboarding()(input);
        media.clearAllResult = const ApiFailure(StorageFailure());
        final useCase = DeleteAllDataUseCase(
          SettingsRepositoryImpl(
            harness.storage,
            settings,
            profile,
            programs,
            clock,
            media,
          ),
          scheduler,
          media,
        );

        final result = await useCase();

        expect(result.isSuccess, isTrue);
        expect(profile.profile(), isNull);
        verify(() => scheduler.cancelWorkoutReminders()).called(1);
        verify(() => scheduler.cancelGoalReminders()).called(1);
        verify(() => scheduler.cancelRestOver()).called(1);
      },
    );
  });
}
