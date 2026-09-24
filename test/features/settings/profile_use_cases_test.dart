import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/app_settings.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/user_profile.dart';
import 'package:gainit/core/domain/services/media_store.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/features/settings/domain/entities/settings_overview.dart';
import 'package:gainit/features/settings/domain/repositories/settings_repository.dart';
import 'package:gainit/features/settings/domain/usecases/settings_use_cases.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_media_store.dart';
import '../../helpers/fixed_clock.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  final clock = FixedClock(DateTime(2026, 3, 1));
  late _MockSettingsRepository repository;

  UserProfile profile({String? photoPath}) => UserProfile(
    id: 'me',
    name: 'Sam',
    heightCm: 180,
    goal: TrainingGoal.gainMuscle,
    trainingStartDate: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    photoPath: photoPath,
  );

  UserProfile saved() =>
      verify(() => repository.saveProfile(captureAny())).captured.single
          as UserProfile;

  setUpAll(() => registerFallbackValue(profile()));

  setUp(() {
    repository = _MockSettingsRepository();
    when(
      () => repository.saveProfile(any()),
    ).thenAnswer((_) async => voidSuccess);
  });

  group('UpdateProfileUseCase', () {
    test('turns an edited age into a birth year', () async {
      final result = await UpdateProfileUseCase(repository, clock)(
        profile(),
        age: 28,
      );

      expect(result.isSuccess, isTrue);
      expect(saved().birthDate, DateTime(1998, 3, 1));
    });

    test('rejects an age outside 13–90', () async {
      final result = await UpdateProfileUseCase(repository, clock)(
        profile(),
        age: 120,
      );

      expect((result as ApiFailure<void>).failure, isA<ValidationFailure>());
      verifyNever(() => repository.saveProfile(any()));
    });
  });

  group('UpdateProfilePhotoUseCase', () {
    test('saves the new photo and removes the previous file', () async {
      final media = FakeMediaStore(pickResult: const ApiSuccess('new.jpg'));

      final result = await UpdateProfilePhotoUseCase(repository, media, clock)(
        profile(photoPath: 'old.jpg'),
        MediaSource.gallery,
      );

      expect(result.isSuccess, isTrue);
      expect(saved().photoPath, 'new.jpg');
      expect(media.deleted, ['old.jpg']);
    });

    test('cancelling the picker changes nothing', () async {
      final media = FakeMediaStore();

      final result = await UpdateProfilePhotoUseCase(repository, media, clock)(
        profile(photoPath: 'old.jpg'),
        MediaSource.camera,
      );

      expect(result.isSuccess, isTrue);
      verifyNever(() => repository.saveProfile(any()));
      expect(media.deleted, isEmpty);
    });

    test('a picker failure is returned and nothing is saved', () async {
      final media = FakeMediaStore(
        pickResult: const ApiFailure(UnexpectedFailure('No permission')),
      );

      final result = await UpdateProfilePhotoUseCase(repository, media, clock)(
        profile(),
        MediaSource.camera,
      );

      expect((result as ApiFailure<void>).failure.message, 'No permission');
      verifyNever(() => repository.saveProfile(any()));
    });

    test('if saving fails the new copy is removed, the old kept', () async {
      when(
        () => repository.saveProfile(any()),
      ).thenAnswer((_) async => const ApiFailure(StorageFailure()));
      final media = FakeMediaStore(pickResult: const ApiSuccess('new.jpg'));

      final result = await UpdateProfilePhotoUseCase(repository, media, clock)(
        profile(photoPath: 'old.jpg'),
        MediaSource.gallery,
      );

      expect(result, isA<ApiFailure<void>>());
      expect(media.deleted, ['new.jpg']);
    });
  });

  group('RemoveProfilePhotoUseCase', () {
    test('clears the path and deletes the file', () async {
      final media = FakeMediaStore();

      final result = await RemoveProfilePhotoUseCase(repository, media, clock)(
        profile(photoPath: 'old.jpg'),
      );

      expect(result.isSuccess, isTrue);
      expect(saved().photoPath, isNull);
      expect(media.deleted, ['old.jpg']);
    });

    test('does nothing when there is no photo', () async {
      final media = FakeMediaStore();

      await RemoveProfilePhotoUseCase(repository, media, clock)(profile());

      verifyNever(() => repository.saveProfile(any()));
      expect(media.deleted, isEmpty);
    });
  });

  group('WatchSettingsUseCase', () {
    test('adds the age today, or none for a profile without one', () async {
      final withAge = UserProfile(
        id: 'me',
        name: 'Sam',
        heightCm: 180,
        goal: TrainingGoal.cut,
        trainingStartDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        birthDate: DateTime(1990, 3, 2),
      );
      when(() => repository.watchOverview()).thenAnswer(
        (_) => Stream.fromIterable([
          ApiSuccess(
            SettingsOverview(settings: const AppSettings(), profile: withAge),
          ),
          ApiSuccess(
            SettingsOverview(settings: const AppSettings(), profile: profile()),
          ),
        ]),
      );

      final ages = await WatchSettingsUseCase(
        repository,
        clock,
      )().map((r) => (r as ApiSuccess<SettingsOverview>).data.age).toList();

      expect(ages, [35, null]);
    });
  });
}
