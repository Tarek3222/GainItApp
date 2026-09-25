import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/clock.dart';
import 'package:gainit/features/daily_goals/domain/usecases/daily_goal_use_cases.dart';
import 'package:gainit/features/onboarding/domain/entities/onboarding_input.dart';
import 'package:gainit/features/onboarding/domain/usecases/complete_onboarding_use_case.dart';
import 'package:gainit/features/onboarding/presentation/cubits/onboarding_cubit.dart';
import 'package:gainit/features/settings/domain/usecases/settings_use_cases.dart';
import 'package:gainit/features/startup/domain/entities/startup_status.dart';
import 'package:gainit/features/startup/domain/usecases/get_startup_status_use_case.dart';
import 'package:gainit/features/startup/presentation/cubits/splash_cubit.dart';
import 'package:gainit/features/workout/domain/usecases/session_actions_use_cases.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';

class _MockGetStatus extends Mock implements GetStartupStatusUseCase {}

class _MockAbandon extends Mock implements AbandonWorkoutUseCase {}

class _MockSyncReminders extends Mock implements SyncGoalRemindersUseCase {}

class _MockSyncWorkoutReminders extends Mock
    implements SyncWorkoutRemindersUseCase {}

class _MockCompleteOnboarding extends Mock
    implements CompleteOnboardingUseCase {}

void main() {
  group('SplashCubit', () {
    late _MockGetStatus getStatus;
    late _MockAbandon abandon;
    late _MockSyncReminders syncReminders;
    late _MockSyncWorkoutReminders syncWorkoutReminders;

    setUp(() {
      getStatus = _MockGetStatus();
      abandon = _MockAbandon();
      syncReminders = _MockSyncReminders();
      when(
        () => syncReminders(completedToday: any(named: 'completedToday')),
      ).thenAnswer((_) async => voidSuccess);
      syncWorkoutReminders = _MockSyncWorkoutReminders();
      when(() => syncWorkoutReminders()).thenAnswer((_) async => voidSuccess);
    });

    SplashCubit build({Duration minimumDisplay = Duration.zero}) => SplashCubit(
      getStatus: getStatus,
      abandonWorkout: abandon,
      syncReminders: syncReminders,
      syncWorkoutReminders: syncWorkoutReminders,
      minimumDisplay: minimumDisplay,
    );

    // testWidgets for its fake clock: no real waiting, no timing flakes.
    testWidgets('stays on the splash for the minimum time on launch', (
      tester,
    ) async {
      when(() => getStatus()).thenAnswer(
        (_) async => const ApiSuccess(StartupStatus(hasProfile: false)),
      );
      final cubit = build(minimumDisplay: const Duration(seconds: 1));
      addTearDown(cubit.close);

      final checked = cubit.check();
      await tester.pump(const Duration(milliseconds: 900));
      expect(cubit.state, const SplashLoading());

      await tester.pump(const Duration(milliseconds: 100));
      await checked;
      expect(cubit.state, const SplashNeedsOnboarding());
    });

    testWidgets('a retry does not wait again', (tester) async {
      when(() => getStatus()).thenAnswer(
        (_) async => const ApiSuccess(StartupStatus(hasProfile: false)),
      );
      final cubit = build(minimumDisplay: const Duration(seconds: 1));
      addTearDown(cubit.close);
      final launch = cubit.check();
      await tester.pump(const Duration(seconds: 1));
      await launch;

      final retry = cubit.check();
      await tester.pump();
      await retry;

      expect(cubit.state, const SplashNeedsOnboarding());
    });

    test('refreshes goal and workout reminders on launch', () async {
      when(() => getStatus()).thenAnswer(
        (_) async => const ApiSuccess(StartupStatus(hasProfile: false)),
      );

      await build().check();

      verify(() => syncReminders()).called(1);
      verify(() => syncWorkoutReminders()).called(1);
    });

    blocTest<SplashCubit, SplashState>(
      'routes to onboarding on first launch',
      setUp: () => when(() => getStatus()).thenAnswer(
        (_) async => const ApiSuccess(StartupStatus(hasProfile: false)),
      ),
      build: build,
      act: (cubit) => cubit.check(),
      expect: () => [const SplashLoading(), const SplashNeedsOnboarding()],
    );

    const interrupted = InterruptedWorkout(
      sessionId: 's1',
      workoutName: 'Chest + Back + Traps',
      completedSets: 8,
      totalSets: 19,
    );

    blocTest<SplashCubit, SplashState>(
      'offers to resume an interrupted workout',
      setUp: () => when(() => getStatus()).thenAnswer(
        (_) async => const ApiSuccess(
          StartupStatus(hasProfile: true, interruptedWorkout: interrupted),
        ),
      ),
      build: build,
      act: (cubit) => cubit.check(),
      expect: () => [
        const SplashLoading(),
        const SplashInterruptedWorkout(interrupted),
      ],
    );

    blocTest<SplashCubit, SplashState>(
      'discarding abandons the session and continues to home',
      setUp: () => when(() => abandon('s1')).thenAnswer(
        (_) async =>
            ApiSuccess(Fixtures.session(status: SessionStatus.abandoned)),
      ),
      build: build,
      act: (cubit) => cubit.discard('s1'),
      expect: () => [const SplashReady()],
    );
  });

  group('OnboardingCubit', () {
    late _MockCompleteOnboarding complete;
    final input = OnboardingInput(
      name: 'Tarek',
      heightCm: 178,
      weightKg: 72,
      age: 30,
      goal: TrainingGoal.gainMuscle,
      trainingStartDate: DateTime(2026, 3, 1),
    );

    setUp(() => complete = _MockCompleteOnboarding());

    blocTest<OnboardingCubit, OnboardingState>(
      'emits Submitting then Success',
      setUp: () =>
          when(() => complete(input)).thenAnswer((_) async => voidSuccess),
      build: () =>
          OnboardingCubit(completeOnboarding: complete, clock: const Clock()),
      act: (cubit) => cubit.submit(input),
      expect: () => [const OnboardingSubmitting(), const OnboardingSuccess()],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'emits Failure with validation messages',
      setUp: () => when(() => complete(input)).thenAnswer(
        (_) async =>
            const ApiFailure(ValidationFailure(['Please enter your name.'])),
      ),
      build: () =>
          OnboardingCubit(completeOnboarding: complete, clock: const Clock()),
      act: (cubit) => cubit.submit(input),
      expect: () => [
        const OnboardingSubmitting(),
        const OnboardingFailure('Please enter your name.'),
      ],
    );
  });
}
