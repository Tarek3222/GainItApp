import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/daily_goal.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/goals/step_day_tracker.dart';
import 'package:gainit/core/errors/exceptions.dart';
import 'package:gainit/core/storage/local_data_sources/daily_goal_local_data_source.dart';
import 'package:gainit/core/storage/storage_integrity_check.dart';

import '../../helpers/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late DailyGoalLocalDataSource goals;
  final now = DateTime(2026, 3, 2, 10);
  const today = 20260302;

  DailyGoal custom(String id, {int order = 5}) => DailyGoal(
    id: id,
    type: DailyGoalType.custom,
    target: 20,
    sortOrder: order,
    createdAt: now,
    title: 'Read',
    unit: 'pages',
  );

  setUp(() async {
    await harness.setUp();
    goals = DailyGoalLocalDataSource(harness.storage);
  });
  tearDown(harness.tearDown);

  group('default goals', () {
    test('water and steps are added on first run', () async {
      await goals.seedDefaultsOnce(now);

      expect(goals.goals().map((g) => g.type), [
        DailyGoalType.water,
        DailyGoalType.steps,
      ]);
      expect(goals.goals().first.target, 3000);
    });

    test('a removed default goal does not come back', () async {
      await goals.seedDefaultsOnce(now);
      await goals.deleteGoal(DailyGoalLocalDataSource.waterGoalId);

      await goals.seedDefaultsOnce(now);

      expect(goals.goals().map((g) => g.type), [DailyGoalType.steps]);
    });
  });

  test('goals are listed in their display order', () async {
    await goals.saveGoal(custom('b', order: 2));
    await goals.saveGoal(custom('a', order: 1));

    expect(goals.goals().map((g) => g.id), ['a', 'b']);
  });

  test('only one water goal is allowed', () async {
    await goals.seedDefaultsOnce(now);

    expect(
      () => goals.saveGoal(
        DailyGoal(
          id: 'other',
          type: DailyGoalType.water,
          target: 2000,
          sortOrder: 9,
          createdAt: now,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('an invalid goal is not saved', () async {
    await expectLater(
      goals.saveGoal(custom('x').copyWith(title: '  ')),
      throwsA(isA<ValidationException>()),
    );
    expect(goals.goals(), isEmpty);
  });

  group('progress', () {
    setUp(() => goals.saveGoal(custom('read')));

    test('adds up through the day', () async {
      await goals.addProgress('read', today, 5, now);
      final change = await goals.addProgress('read', today, 3, now);

      expect(change, (total: 8.0, applied: 3.0));
      expect(goals.logsSince(today).single.amount, 8);
    });

    test('taking back more than logged stops at 0', () async {
      await goals.addProgress('read', today, 5, now);

      // Only the 5 that were logged can be taken back.
      expect(await goals.addProgress('read', today, -9, now), (
        total: 0.0,
        applied: -5.0,
      ));
    });

    test('each day has its own log', () async {
      await goals.addProgress('read', today, 5, now);
      await goals.addProgress('read', 20260303, 2, now);

      expect(goals.logsSince(20260303).single.amount, 2);
    });

    test('an unknown goal is rejected', () {
      expect(
        () => goals.addProgress('missing', today, 1, now),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('removing a goal removes its logs', () async {
      await goals.addProgress('read', today, 5, now);

      await goals.deleteGoal('read');

      expect(harness.storage.dailyGoalLogs.isEmpty, isTrue);
    });
  });

  test('startup repair removes logs whose goal is gone', () async {
    await harness.storage.dailyGoalLogs.put(
      'ghost',
      DailyGoalLog(
        id: 'ghost',
        goalId: 'deleted',
        dayKey: today,
        amount: 1,
        updatedAt: now,
      ),
    );

    await StorageIntegrityCheck(harness.storage).run();

    expect(harness.storage.dailyGoalLogs.isEmpty, isTrue);
  });

  test('the step sensor state survives a restart', () async {
    const state = StepTrackerState(
      dayKey: today,
      baseline: -200,
      lastCount: 900,
    );

    await goals.saveStepState(state);

    expect(goals.stepState(), state);
  });

  test('clearing all data removes goals and logs', () async {
    await goals.saveGoal(custom('read'));
    await goals.addProgress('read', today, 1, now);

    await harness.storage.clearAll();

    expect(harness.storage.dailyGoals.isEmpty, isTrue);
    expect(harness.storage.dailyGoalLogs.isEmpty, isTrue);
  });
}
