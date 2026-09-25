import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/goals/step_day_tracker.dart';
import 'package:gainit/core/domain/utils/dates.dart';

void main() {
  final monday = DateTime(2026, 3, 2);
  StepTrackerState state(DateTime day, int baseline, int lastCount) =>
      StepTrackerState(
        dayKey: dayKeyOf(day),
        baseline: baseline,
        lastCount: lastCount,
      );

  test('the first reading ever starts the day at 0', () {
    final next = StepDayTracker.update(
      null,
      5000,
      monday.add(const Duration(hours: 9)),
    );

    expect(next, state(monday, 5000, 5000));
    expect(next.steps, 0);
  });

  test('later readings the same day add up', () {
    final next = StepDayTracker.update(
      state(monday, 5000, 5000),
      6200,
      monday.add(const Duration(hours: 12)),
    );

    expect(next.steps, 1200);
  });

  test('a reboot mid-day keeps the steps counted so far', () {
    // 1200 steps, then the phone restarts and the sensor counts from 0.
    final next = StepDayTracker.update(
      state(monday, 5000, 6200),
      300,
      monday.add(const Duration(hours: 14)),
    );

    expect(next.steps, 1500);
  });

  test('steps since yesterday\'s last reading count for today', () {
    final tuesday = DateTime(2026, 3, 3);

    final next = StepDayTracker.update(
      state(monday, 5000, 9000),
      9800,
      tuesday.add(const Duration(hours: 8)),
    );

    expect(next, state(tuesday, 9000, 9800));
    expect(next.steps, 800);
  });

  test('a reboot overnight counts every step since the reboot', () {
    final next = StepDayTracker.update(
      state(monday, 5000, 9000),
      400,
      DateTime(2026, 3, 3, 8),
    );

    expect(next.steps, 400);
  });

  test('after days without readings counting restarts from now', () {
    final next = StepDayTracker.update(
      state(monday, 5000, 9000),
      30000,
      DateTime(2026, 3, 6, 8),
    );

    expect(next.steps, 0);
  });

  test('stepsOn ignores a state from another day', () {
    final s = state(monday, 5000, 6000);

    expect(
      StepDayTracker.stepsOn(s, monday.add(const Duration(hours: 20))),
      1000,
    );
    expect(StepDayTracker.stepsOn(s, DateTime(2026, 3, 3)), 0);
    expect(StepDayTracker.stepsOn(null, monday), 0);
  });
}
