import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/app_settings.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/features/workout/domain/usecases/rest_timer_use_cases.dart';
import 'package:gainit/features/workout/presentation/cubits/rest_timer_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixed_clock.dart';

class _MockGetSettings extends Mock implements GetRestTimerSettingsUseCase {}

class _MockSchedule extends Mock implements ScheduleRestAlertUseCase {}

class _MockCancel extends Mock implements CancelRestAlertUseCase {}

class _MockPrepare extends Mock implements PrepareRestAlertsUseCase {}

void main() {
  late FixedClock clock;
  late _MockGetSettings getSettings;
  late _MockSchedule schedule;
  late _MockCancel cancel;
  late _MockPrepare prepare;

  setUp(() {
    clock = FixedClock(DateTime(2026, 3, 2, 18));
    getSettings = _MockGetSettings();
    schedule = _MockSchedule();
    cancel = _MockCancel();
    prepare = _MockPrepare();
    when(() => prepare()).thenAnswer((_) async => true);
    when(() => cancel()).thenAnswer((_) async {});
    when(
      () => schedule(
        endsAt: any(named: 'endsAt'),
        exerciseName: any(named: 'exerciseName'),
      ),
    ).thenAnswer((_) async {});
  });

  RestTimerCubit build() => RestTimerCubit(
    clock: clock,
    getSettings: getSettings,
    scheduleAlert: schedule,
    cancelAlert: cancel,
    prepareAlerts: prepare,
    // Long interval: tests drive time explicitly through the clock + tick().
    tickInterval: const Duration(hours: 1),
  );

  test('starts idle', () {
    final cubit = build();
    expect(cubit.state.status, RestTimerStatus.idle);
    cubit.close();
  });

  blocTest<RestTimerCubit, RestTimerState>(
    'counts down from the wall clock and finishes at zero',
    build: build,
    act: (cubit) {
      cubit.start(seconds: 90, exerciseName: 'Bench');
      clock.advance(const Duration(seconds: 30));
      cubit.tick();
      clock.advance(const Duration(seconds: 61));
      cubit.tick();
    },
    verify: (cubit) {
      expect(cubit.state.status, RestTimerStatus.finished);
      expect(cubit.state.remaining, Duration.zero);
    },
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'reports the correct remaining time after a long gap (backgrounded)',
    build: build,
    act: (cubit) {
      cubit.start(seconds: 120, exerciseName: 'Bench');
      clock.advance(const Duration(seconds: 75));
      cubit.tick();
    },
    verify: (cubit) =>
        expect(cubit.state.remaining, const Duration(seconds: 45)),
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'pause freezes the remaining time and resume continues from it',
    build: build,
    act: (cubit) {
      cubit.start(seconds: 60, exerciseName: 'Bench');
      clock.advance(const Duration(seconds: 20));
      cubit.pause();
      clock.advance(const Duration(minutes: 5));
      cubit
        ..tick()
        ..resume();
      clock.advance(const Duration(seconds: 10));
      cubit.tick();
    },
    verify: (cubit) {
      expect(cubit.state.status, RestTimerStatus.running);
      expect(cubit.state.remaining, const Duration(seconds: 30));
    },
  );

  blocTest<RestTimerCubit, RestTimerState>(
    '+15 s and −15 s adjust the end time',
    build: build,
    act: (cubit) {
      cubit.start(seconds: 60, exerciseName: 'Bench');
      cubit
        ..adjust(RestTimerCubit.adjustStep)
        ..adjust(RestTimerCubit.adjustStep)
        ..adjust(-RestTimerCubit.adjustStep);
    },
    verify: (cubit) =>
        expect(cubit.state.remaining, const Duration(seconds: 75)),
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'skip returns to idle and cancels the background alert',
    build: build,
    act: (cubit) => cubit
      ..start(seconds: 60, exerciseName: 'Bench')
      ..skip(),
    verify: (cubit) {
      expect(cubit.state.status, RestTimerStatus.idle);
      // Once for skip, once when the cubit closes.
      verify(() => cancel()).called(2);
    },
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'a rest of 0 s (superset) never starts',
    build: build,
    act: (cubit) => cubit.start(seconds: 0, exerciseName: 'Curl'),
    verify: (cubit) => expect(cubit.state.status, RestTimerStatus.idle),
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'schedules the alert only while the app is in the background',
    build: build,
    act: (cubit) => cubit
      ..start(seconds: 60, exerciseName: 'Bench')
      ..onAppBackgrounded()
      ..onAppResumed(),
    verify: (_) {
      verify(
        () => schedule(
          endsAt: DateTime(2026, 3, 2, 18, 1),
          exerciseName: 'Bench',
        ),
      ).called(1);
      // Once on resume, once when the cubit closes.
      verify(() => cancel()).called(2);
    },
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'loads user timer settings',
    setUp: () => when(() => getSettings()).thenAnswer(
      (_) async => const ApiSuccess(AppSettings(autoStartRestTimer: false)),
    ),
    build: build,
    act: (cubit) => cubit.loadSettings(),
    expect: () => [
      const RestTimerState(settings: AppSettings(autoStartRestTimer: false)),
    ],
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'asks for notification permission when rest alerts are on',
    setUp: () => when(
      () => getSettings(),
    ).thenAnswer((_) async => const ApiSuccess(AppSettings())),
    build: build,
    act: (cubit) => cubit.loadSettings(),
    verify: (_) => verify(() => prepare()).called(1),
  );

  blocTest<RestTimerCubit, RestTimerState>(
    'with rest alerts off: no permission prompt and no background alert',
    setUp: () => when(() => getSettings()).thenAnswer(
      (_) async => const ApiSuccess(AppSettings(restAlertsEnabled: false)),
    ),
    build: build,
    act: (cubit) async {
      await cubit.loadSettings();
      cubit
        ..start(seconds: 60, exerciseName: 'Bench')
        ..onAppBackgrounded();
    },
    verify: (_) {
      verifyNever(() => prepare());
      verifyNever(
        () => schedule(
          endsAt: any(named: 'endsAt'),
          exerciseName: any(named: 'exerciseName'),
        ),
      );
    },
  );
}
