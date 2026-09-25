import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/daily_goal.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/validation/validators.dart';

void main() {
  DailyGoal goal(DailyGoalType type, double target, {double increment = 1}) =>
      DailyGoal(
        id: 'g',
        type: type,
        target: target,
        sortOrder: 0,
        createdAt: DateTime(2026),
        title: 'Goal',
        increment: increment,
      );

  test('a step target below the stored quick-add amount is valid', () {
    expect(
      Validators.dailyGoal(goal(DailyGoalType.steps, 500, increment: 1000)),
      isEmpty,
    );
  });

  test('an 8 fl oz water target is valid', () {
    expect(
      Validators.dailyGoal(goal(DailyGoalType.water, 236.6, increment: 250)),
      isEmpty,
    );
  });

  test('a custom quick-add amount cannot exceed the target', () {
    expect(Validators.dailyGoal(goal(DailyGoalType.custom, 5, increment: 10)), [
      'The quick-add amount cannot be more than the target.',
    ]);
  });

  test('a custom quick-add amount must be above 0', () {
    expect(Validators.dailyGoal(goal(DailyGoalType.custom, 5, increment: 0)), [
      'The quick-add amount must be above 0.',
    ]);
  });

  test('reminders must end after they start', () {
    expect(
      Validators.dailyGoal(
        goal(
          DailyGoalType.water,
          3000,
        ).copyWith(reminderStartMinutes: 20 * 60, reminderEndMinutes: 8 * 60),
      ),
      ['The last reminder cannot be before the first.'],
    );
  });
}
