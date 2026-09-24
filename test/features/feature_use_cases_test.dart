import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/app_settings.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/features/history/domain/entities/history_entities.dart';
import 'package:gainit/features/onboarding/domain/entities/onboarding_input.dart';
import 'package:gainit/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:gainit/features/onboarding/domain/usecases/complete_onboarding_use_case.dart';
import 'package:gainit/features/progress/domain/entities/progress_entities.dart';
import 'package:gainit/features/progress/domain/usecases/progress_use_cases.dart';
import 'package:gainit/features/settings/domain/repositories/settings_repository.dart';
import 'package:gainit/features/settings/domain/usecases/settings_use_cases.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixed_clock.dart';
import '../helpers/fixtures.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockScheduler extends Mock implements NotificationScheduler {}

void main() {
  group('CompleteOnboardingUseCase', () {
    final useCase = CompleteOnboardingUseCase(
      _MockOnboardingRepository(),
      FixedClock(DateTime(2026, 3, 1)),
      const IdGenerator(),
    );

    test('rejects an empty name and an unrealistic height', () async {
      final result = await useCase(
        OnboardingInput(
          name: '  ',
          heightCm: 20,
          weightKg: 72,
          age: 30,
          goal: TrainingGoal.gainMuscle,
          trainingStartDate: DateTime(2026, 3, 1),
        ),
      );

      final failure = (result as ApiFailure<void>).failure as ValidationFailure;
      expect(failure.errors, hasLength(2));
    });
  });

  group('HistoryFilter.matches', () {
    final record = SessionRecord(
      session: Fixtures.session(
        status: SessionStatus.completed,
        completedAt: DateTime(2026, 3, 2, 19),
      ),
      exercises: [Fixtures.sessionExercise()],
      sets: [Fixtures.set()],
    );

    test('matches by muscle trained', () {
      expect(
        const HistoryFilter(muscle: MuscleGroup.chest).matches(record),
        isTrue,
      );
      expect(
        const HistoryFilter(muscle: MuscleGroup.quads).matches(record),
        isFalse,
      );
    });

    test('matches by exercise', () {
      expect(
        const HistoryFilter(exerciseId: 'ex_bench').matches(record),
        isTrue,
      );
      expect(
        const HistoryFilter(exerciseId: 'ex_squat').matches(record),
        isFalse,
      );
    });

    test('date range is inclusive of both days', () {
      final day = DateTime(2026, 3, 2);
      expect(HistoryFilter(from: day, to: day).matches(record), isTrue);
      expect(
        HistoryFilter(from: DateTime(2026, 3, 3)).matches(record),
        isFalse,
      );
    });
  });

  group('GetExerciseProgressUseCase.build', () {
    test('finds bests and orders the trend oldest first', () {
      final progress = GetExerciseProgressUseCase.build(
        ExerciseHistoryData(
          exercise: (id: 'ex', name: 'Bench', muscle: MuscleGroup.chest),
          sessions: [
            Fixtures.performance([(32.5, 8)], date: DateTime(2026, 3, 9)),
            Fixtures.performance([(30, 12)], date: DateTime(2026, 3, 2)),
          ],
        ),
      );

      expect(progress.bestWeight, 32.5);
      expect(progress.bestReps, 12);
      expect(progress.bestOneRepMax, 42);
      expect(progress.trend.first.date, DateTime(2026, 3, 2));
    });
  });

  group('UpdateSettingsUseCase', () {
    late _MockSettingsRepository repository;
    late _MockScheduler scheduler;

    setUpAll(() => registerFallbackValue(const AppSettings()));
    setUp(() {
      repository = _MockSettingsRepository();
      scheduler = _MockScheduler();
    });

    test('does not enable reminders when permission is denied', () async {
      when(() => scheduler.requestPermission()).thenAnswer((_) async => false);

      final result = await UpdateSettingsUseCase(repository, scheduler)(
        previous: const AppSettings(),
        next: const AppSettings(remindersEnabled: true),
      );

      expect(result, isA<ApiFailure<void>>());
      verifyNever(() => repository.saveSettings(any()));
    });

    test('schedules reminders for workout days when enabled', () async {
      when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
      when(
        () => repository.saveSettings(any()),
      ).thenAnswer((_) async => voidSuccess);
      when(() => repository.workoutDays()).thenAnswer(
        (_) async => const ApiSuccess([(weekday: 1, workoutName: 'Legs')]),
      );
      when(
        () => scheduler.scheduleWorkoutReminders(
          days: any(named: 'days'),
          minutesOfDay: any(named: 'minutesOfDay'),
        ),
      ).thenAnswer((_) async {});

      final result = await UpdateSettingsUseCase(repository, scheduler)(
        previous: const AppSettings(),
        next: const AppSettings(remindersEnabled: true),
      );

      expect(result.isSuccess, isTrue);
      verify(
        () => scheduler.scheduleWorkoutReminders(
          days: [(weekday: 1, workoutName: 'Legs')],
          minutesOfDay: const AppSettings().reminderMinutesOfDay,
        ),
      ).called(1);
    });

    test('does not touch reminders when only timer settings change', () async {
      when(
        () => repository.saveSettings(any()),
      ).thenAnswer((_) async => voidSuccess);

      await UpdateSettingsUseCase(repository, scheduler)(
        previous: const AppSettings(),
        next: const AppSettings(soundEnabled: false),
      );

      verifyNever(() => scheduler.cancelWorkoutReminders());
      verifyNever(() => scheduler.requestPermission());
    });
  });
}
