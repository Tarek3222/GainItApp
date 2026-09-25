import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/daily_goal.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/goals/step_day_tracker.dart';
import 'package:gainit/core/domain/services/day_change_source.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/domain/services/step_counter.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/core/storage/local_data_sources/daily_goal_local_data_source.dart';
import 'package:gainit/features/daily_goals/data/repositories/daily_goal_repository_impl.dart';
import 'package:gainit/features/daily_goals/domain/entities/daily_goal_entities.dart';
import 'package:gainit/features/daily_goals/domain/usecases/daily_goal_use_cases.dart';

import '../../helpers/fake_notification_scheduler.dart';
import '../../helpers/fake_step_counter.dart';
import '../../helpers/fixed_clock.dart';
import '../../helpers/hive_test_harness.dart';

class _DayChanges implements DayChangeSource {
  final _controller = StreamController<void>.broadcast();

  void fire() => _controller.add(null);

  @override
  Stream<void> get changes => _controller.stream;
}

class _Ids implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'id${_next++}';
}

void main() {
  final harness = HiveTestHarness();
  late DailyGoalLocalDataSource source;
  late DailyGoalRepositoryImpl repository;
  late FakeStepCounter counter;
  late FakeNotificationScheduler scheduler;
  late FixedClock clock;
  late SyncGoalRemindersUseCase sync;

  const today = 20260302;

  setUp(() async {
    await harness.setUp();
    source = DailyGoalLocalDataSource(harness.storage);
    repository = DailyGoalRepositoryImpl(source);
    counter = FakeStepCounter();
    scheduler = FakeNotificationScheduler();
    clock = FixedClock(DateTime(2026, 3, 2, 10));
    sync = SyncGoalRemindersUseCase(repository, scheduler, clock);
    await source.seedDefaultsOnce(clock.now());
  });
  tearDown(harness.tearDown);

  WatchTodayStepsUseCase steps({Duration saveEvery = Duration.zero}) =>
      WatchTodayStepsUseCase(counter, repository, clock, saveEvery: saveEvery);

  group('WatchTodayStepsUseCase', () {
    for (final (access, status) in [
      (StepAccess.denied, StepStatus.needsPermission),
      (StepAccess.permanentlyDenied, StepStatus.blocked),
      (StepAccess.unsupported, StepStatus.unavailable),
    ]) {
      test('$access shows $status and never reads the sensor', () async {
        counter.access = access;

        final readings = await steps()().toList();

        expect(readings.single.status, status);
        expect(counter.isListening, isFalse);
      });
    }

    test('counts steps from the first reading of the day', () async {
      final readings = <StepReading>[];
      final sub = steps()().listen(readings.add);
      await pumpEventQueue();

      counter.emit(5000);
      await pumpEventQueue();
      counter.emit(5400);
      await pumpEventQueue();

      expect(readings.map((r) => (r.status, r.steps)), [
        (StepStatus.active, 0),
        (StepStatus.active, 0),
        (StepStatus.active, 400),
      ]);
      await sub.cancel();
      await pumpEventQueue();
      expect(source.stepState()?.steps, 400);
    });

    test('picks up where the last session left off today', () async {
      await source.saveStepState(
        const StepTrackerState(dayKey: today, baseline: 1000, lastCount: 3000),
      );

      final first = await steps()().first;

      expect(first.steps, 2000);
      expect(first.dayKey, today);
    });

    test('saves the sensor state at most every interval', () async {
      final sub = steps(saveEvery: const Duration(minutes: 1))().listen((_) {});
      await pumpEventQueue();

      counter.emit(100); // First reading: saved.
      await pumpEventQueue();
      clock.advance(const Duration(seconds: 10));
      counter.emit(150); // Too soon: not saved yet.
      await pumpEventQueue();
      await pumpEventQueue();

      expect(source.stepState()?.lastCount, 100);
      await sub.cancel();
      // Stopping saves the latest reading.
      expect(source.stepState()?.lastCount, 150);
    });

    test('a phone without a step sensor falls back to manual steps', () async {
      final readings = <StepReading>[];
      final sub = steps()().listen(readings.add);
      await pumpEventQueue();

      counter.fail();
      await pumpEventQueue();

      expect(readings.last.status, StepStatus.unavailable);
      await sub.cancel();
    });
  });

  group('WatchTodayGoalsUseCase', () {
    late _DayChanges dayChanges;

    setUp(() => dayChanges = _DayChanges());

    WatchTodayGoalsUseCase useCase() =>
        WatchTodayGoalsUseCase(repository, steps(), clock, dayChanges, sync);

    Future<TodayGoals> latest(List<ApiResult<TodayGoals>> results) async {
      await pumpEventQueue();
      return (results.last as ApiSuccess<TodayGoals>).data;
    }

    test(
      'shows today\'s water and adds sensor steps to logged steps',
      () async {
        await source.addProgress(
          DailyGoalLocalDataSource.waterGoalId,
          20260301,
          900,
          clock.now(),
        );
        await source.addProgress(
          DailyGoalLocalDataSource.waterGoalId,
          today,
          500,
          clock.now(),
        );
        await source.addProgress(
          DailyGoalLocalDataSource.stepsGoalId,
          today,
          1000,
          clock.now(),
        );
        final results = <ApiResult<TodayGoals>>[];
        final sub = useCase()().listen(results.add);
        await pumpEventQueue();
        counter
          ..emit(2000)
          ..emit(2600);

        final goals = await latest(results);

        final [water, walking] = goals.goals;
        expect(water.amount, 500);
        expect(walking.amount, 1600);
        expect(walking.sensorAmount, 600);
        expect(goals.stepStatus, StepStatus.active);
        await sub.cancel();
      },
    );

    test('progress starts from zero after midnight', () async {
      await source.addProgress(
        DailyGoalLocalDataSource.waterGoalId,
        today,
        500,
        clock.now(),
      );
      final results = <ApiResult<TodayGoals>>[];
      final sub = useCase()().listen(results.add);
      expect((await latest(results)).goals.first.amount, 500);

      clock.current = DateTime(2026, 3, 3, 0, 1);
      dayChanges.fire();

      expect((await latest(results)).goals.first.amount, 0);
      await sub.cancel();
    });

    test('reaching a goal pauses its reminders until tomorrow', () async {
      await source.saveGoal(
        (await _goal(
          source,
          DailyGoalLocalDataSource.waterGoalId,
        )).copyWith(reminderEnabled: true),
      );
      final results = <ApiResult<TodayGoals>>[];
      final sub = useCase()().listen(results.add);
      await latest(results);

      await source.addProgress(
        DailyGoalLocalDataSource.waterGoalId,
        today,
        3000,
        clock.now(),
      );
      await latest(results);
      await pumpEventQueue();

      expect(scheduler.goalReminders, isNotEmpty);
      expect(scheduler.goalReminders!.every((r) => r.skipToday), isTrue);
      await sub.cancel();
    });
  });

  group('WatchTodayGoalsUseCase with the step sensor', () {
    late _DayChanges dayChanges;

    setUp(() => dayChanges = _DayChanges());

    test('a step goal reached by walking pauses its reminders, even '
        'before the step count is saved', () async {
      await source.saveGoal(
        (await _goal(
          source,
          DailyGoalLocalDataSource.stepsGoalId,
        )).copyWith(reminderEnabled: true),
      );
      final sub = WatchTodayGoalsUseCase(
        repository,
        steps(saveEvery: const Duration(minutes: 1)),
        clock,
        dayChanges,
        sync,
      )().listen((_) {});
      await pumpEventQueue();
      counter.emit(5000); // First reading: saved as the day's baseline.
      await pumpEventQueue();
      clock.advance(const Duration(seconds: 10));
      counter.emit(15010); // 10,010 steps; too soon to be saved.
      await pumpEventQueue();
      await pumpEventQueue();

      expect(source.stepState()?.steps, 0);
      expect(scheduler.goalReminders, isNotEmpty);
      expect(scheduler.goalReminders!.every((r) => r.skipToday), isTrue);
      await sub.cancel();
    });

    test('the sensor is not read without a step goal', () async {
      await source.deleteGoal(DailyGoalLocalDataSource.stepsGoalId);
      final results = <ApiResult<TodayGoals>>[];
      final sub = WatchTodayGoalsUseCase(
        repository,
        steps(),
        clock,
        dayChanges,
        sync,
      )().listen(results.add);
      await pumpEventQueue();

      expect(counter.isListening, isFalse);
      expect(results, isNotEmpty);
      await sub.cancel();
    });
  });

  group('SaveGoalUseCase', () {
    SaveGoalUseCase useCase() =>
        SaveGoalUseCase(repository, scheduler, sync, clock, _Ids());

    test('adds a custom goal after the others, with a clean name', () async {
      final result = await useCase()(
        const GoalInput(
          type: DailyGoalType.custom,
          target: 20,
          title: '  Read ',
          unit: ' pages ',
        ),
      );

      expect(result, voidSuccess);
      final added = source.goals().last;
      expect(added.title, 'Read');
      expect(added.unit, 'pages');
      expect(added.sortOrder, 2);
      expect(scheduler.permissionRequests, 0);
    });

    test('turning reminders on asks for permission and schedules', () async {
      final water = await _goal(source, DailyGoalLocalDataSource.waterGoalId);

      final result = await useCase()(
        GoalInput.fromGoal(water).copyWith(reminderEnabled: true),
        existing: water,
      );

      expect(result, voidSuccess);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.goalReminders, hasLength(7));
    });

    test('without notification permission nothing is saved', () async {
      scheduler.permissionGranted = false;
      final water = await _goal(source, DailyGoalLocalDataSource.waterGoalId);

      final result = await useCase()(
        GoalInput.fromGoal(water).copyWith(reminderEnabled: true),
        existing: water,
      );

      expect((result as ApiFailure<void>).failure, isA<InvalidStateFailure>());
      expect((await _goal(source, water.id)).reminderEnabled, isFalse);
    });

    test('a small step target saves (default quick-add is larger)', () async {
      final steps = await _goal(source, DailyGoalLocalDataSource.stepsGoalId);

      final result = await useCase()(
        GoalInput.fromGoal(steps).copyWith(target: 500),
        existing: steps,
      );

      expect(result, voidSuccess);
      expect((await _goal(source, steps.id)).target, 500);
    });

    test(
      'reminders across all goals are capped at the platform limit',
      () async {
        final water = (await _goal(
          source,
          DailyGoalLocalDataSource.waterGoalId,
        )).copyWith(reminderEnabled: true, reminderIntervalMinutes: 30);
        await source.saveGoal(water); // 25 reminders a day.

        final result = await useCase()(
          const GoalInput(
            type: DailyGoalType.custom,
            target: 20,
            title: 'Read',
            reminderEnabled: true,
            reminderIntervalMinutes: 30,
          ),
        );

        expect((result as ApiFailure<void>).failure, isA<ValidationFailure>());
        expect(scheduler.permissionRequests, 0);
      },
    );

    test(
      'a second water goal is refused without asking for anything',
      () async {
        final result = await useCase()(
          GoalInput.defaultsFor(
            DailyGoalType.water,
          ).copyWith(reminderEnabled: true),
        );

        expect((result as ApiFailure<void>).failure, isA<ValidationFailure>());
        expect(scheduler.permissionRequests, 0);
      },
    );

    test('editing a goal removed elsewhere does not bring it back', () async {
      final water = await _goal(source, DailyGoalLocalDataSource.waterGoalId);
      await source.deleteGoal(water.id);

      final result = await useCase()(
        GoalInput.fromGoal(water).copyWith(target: 2000),
        existing: water,
      );

      expect((result as ApiFailure<void>).failure, isA<NotFoundFailure>());
      expect(source.goals().any((g) => g.id == water.id), isFalse);
    });

    test('an invalid target is rejected before saving', () async {
      final result = await useCase()(
        const GoalInput(type: DailyGoalType.steps, target: 0),
      );

      expect((result as ApiFailure<void>).failure, isA<ValidationFailure>());
    });
  });

  test('removing a goal with reminders cancels them', () async {
    final water = (await _goal(
      source,
      DailyGoalLocalDataSource.waterGoalId,
    )).copyWith(reminderEnabled: true);
    await source.saveGoal(water);

    await RemoveGoalUseCase(repository, sync)(water);

    expect(source.goals().map((g) => g.type), [DailyGoalType.steps]);
    expect(scheduler.goalCancelCalls, 1);
  });

  group('LogGoalProgressUseCase', () {
    test('adds to today\'s progress', () async {
      final result = await LogGoalProgressUseCase(repository, clock)(
        DailyGoalLocalDataSource.waterGoalId,
        250,
      );

      expect(result, const ApiSuccess(250.0));
      expect(source.logsSince(today).single.dayKey, today);
    });

    test('rejects an empty amount', () async {
      final result = await LogGoalProgressUseCase(repository, clock)(
        DailyGoalLocalDataSource.waterGoalId,
        0,
      );

      expect(result, isA<ApiFailure<double>>());
    });
  });

  group('SyncGoalRemindersUseCase', () {
    test('uses the stored step count to spot a reached step goal', () async {
      await source.saveGoal(
        (await _goal(source, DailyGoalLocalDataSource.stepsGoalId)).copyWith(
          reminderEnabled: true,
          reminderStartMinutes: 12 * 60,
          reminderEndMinutes: 12 * 60,
        ),
      );
      await source.saveStepState(
        const StepTrackerState(dayKey: today, baseline: 0, lastCount: 12000),
      );

      await sync();

      expect(scheduler.goalReminders, hasLength(1));
      expect(scheduler.goalReminders!.single.skipToday, isTrue);
    });

    test('without any reminders everything is cancelled', () async {
      await sync();

      expect(scheduler.goalCancelCalls, 1);
      expect(scheduler.goalScheduleCalls, 0);
    });

    test('an unchanged plan is not scheduled again', () async {
      await source.saveGoal(
        (await _goal(
          source,
          DailyGoalLocalDataSource.waterGoalId,
        )).copyWith(reminderEnabled: true),
      );

      await sync();
      await sync();

      expect(scheduler.goalScheduleCalls, 1);
    });

    test('a new app or phone language reschedules the same plan', () async {
      await source.saveGoal(
        (await _goal(
          source,
          DailyGoalLocalDataSource.waterGoalId,
        )).copyWith(reminderEnabled: true),
      );
      await sync();

      scheduler.textLanguage = 'ar';
      await sync();

      expect(scheduler.goalScheduleCalls, 2);
    });

    test('a plan that skipped today is rescheduled the next day', () async {
      await source.saveGoal(
        (await _goal(
          source,
          DailyGoalLocalDataSource.waterGoalId,
        )).copyWith(reminderEnabled: true),
      );
      await source.addProgress(
        DailyGoalLocalDataSource.waterGoalId,
        today,
        3000,
        clock.now(),
      );
      await sync();
      expect(scheduler.goalReminders!.first.skipToday, isTrue);

      clock.current = DateTime(2026, 3, 3, 8);
      await sync();

      expect(scheduler.goalScheduleCalls, 2);
      expect(scheduler.goalReminders!.first.skipToday, isFalse);
    });

    test('a failed run does not block the next one', () async {
      final failing = SyncGoalRemindersUseCase(
        repository,
        _ThrowingOnceScheduler(scheduler),
        clock,
      );
      await source.saveGoal(
        (await _goal(
          source,
          DailyGoalLocalDataSource.waterGoalId,
        )).copyWith(reminderEnabled: true),
      );

      expect(await failing(), isA<ApiFailure<void>>());
      expect(await failing(), voidSuccess);
      expect(scheduler.goalReminders, hasLength(7));
    });
  });
}

/// Throws on the first goal schedule, then delegates.
class _ThrowingOnceScheduler extends FakeNotificationScheduler {
  _ThrowingOnceScheduler(this._inner);

  final FakeNotificationScheduler _inner;
  var _thrown = false;

  @override
  Future<void> scheduleGoalReminders(List<GoalReminder> reminders) async {
    if (!_thrown) {
      _thrown = true;
      throw StateError('platform error');
    }
    await _inner.scheduleGoalReminders(reminders);
  }
}

Future<DailyGoal> _goal(DailyGoalLocalDataSource source, String id) async =>
    source.goals().firstWhere((g) => g.id == id);
