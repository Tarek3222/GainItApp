import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';

/// Goals with their recent progress logs, as stored.
class GoalData extends Equatable {
  const GoalData({required this.goals, required this.logs});

  /// In display order.
  final List<DailyGoal> goals;
  final List<DailyGoalLog> logs;

  @override
  List<Object?> get props => [goals, logs];
}

/// State of the phone's step sensor for the step goal.
enum StepStatus {
  /// Counting steps.
  active,

  /// Step counting needs the user's permission.
  needsPermission,

  /// Permission was refused for good; only system settings can allow it.
  blocked,

  /// The phone has no usable step sensor. Steps can be added by hand.
  unavailable,
}

/// Today's steps from the sensor.
class StepReading extends Equatable {
  const StepReading({required this.status, this.dayKey, this.steps = 0});

  final StepStatus status;

  /// Day [steps] belong to, as `yyyymmdd`; `null` before any reading.
  final int? dayKey;
  final int steps;

  @override
  List<Object?> get props => [status, dayKey, steps];
}

/// One goal and how far along it is today.
class GoalProgress extends Equatable {
  const GoalProgress({
    required this.goal,
    required this.amount,
    this.sensorAmount = 0,
  });

  final DailyGoal goal;

  /// Everything counted today, including [sensorAmount].
  final double amount;

  /// The part of [amount] counted by the step sensor.
  final double sensorAmount;

  /// 0–1 for the progress ring.
  double get fraction {
    final value = amount / goal.target;
    return value.isFinite ? value.clamp(0, 1).toDouble() : 0;
  }

  bool get isComplete => amount >= goal.target;

  @override
  List<Object?> get props => [goal, amount, sensorAmount];
}

/// Today's goals for the "Today's progress" card.
class TodayGoals extends Equatable {
  const TodayGoals({required this.goals, required this.stepStatus});

  final List<GoalProgress> goals;
  final StepStatus stepStatus;

  int get completedCount => goals.where((g) => g.isComplete).length;

  bool get isEmpty => goals.isEmpty;

  @override
  List<Object?> get props => [goals, stepStatus];
}

/// What the goal editor produces.
class GoalInput extends Equatable {
  const GoalInput({
    required this.type,
    required this.target,
    this.title = '',
    this.unit = '',
    this.increment = 1,
    this.reminderEnabled = false,
    this.reminderIntervalMinutes = 120,
    this.reminderStartMinutes = 9 * 60,
    this.reminderEndMinutes = 21 * 60,
  });

  /// Editor defaults for a new goal of [type].
  factory GoalInput.defaultsFor(DailyGoalType type) => switch (type) {
    DailyGoalType.water => const GoalInput(
      type: DailyGoalType.water,
      target: 3000,
      increment: 250,
    ),
    DailyGoalType.steps => const GoalInput(
      type: DailyGoalType.steps,
      target: 10000,
      increment: 1000,
    ),
    DailyGoalType.custom => const GoalInput(
      type: DailyGoalType.custom,
      target: 1,
    ),
  };

  factory GoalInput.fromGoal(DailyGoal goal) => GoalInput(
    type: goal.type,
    target: goal.target,
    title: goal.title,
    unit: goal.unit,
    increment: goal.increment,
    reminderEnabled: goal.reminderEnabled,
    reminderIntervalMinutes: goal.reminderIntervalMinutes,
    reminderStartMinutes: goal.reminderStartMinutes,
    reminderEndMinutes: goal.reminderEndMinutes,
  );

  final DailyGoalType type;
  final double target;
  final String title;
  final String unit;
  final double increment;
  final bool reminderEnabled;
  final int reminderIntervalMinutes;
  final int reminderStartMinutes;
  final int reminderEndMinutes;

  /// Reminders a day with these settings; 0 when they are off or the
  /// times are out of order.
  int get remindersPerDay =>
      !reminderEnabled ||
          reminderIntervalMinutes <= 0 ||
          reminderEndMinutes < reminderStartMinutes
      ? 0
      : (reminderEndMinutes - reminderStartMinutes) ~/ reminderIntervalMinutes +
            1;

  GoalInput copyWith({
    double? target,
    String? title,
    String? unit,
    double? increment,
    bool? reminderEnabled,
    int? reminderIntervalMinutes,
    int? reminderStartMinutes,
    int? reminderEndMinutes,
  }) {
    return GoalInput(
      type: type,
      target: target ?? this.target,
      title: title ?? this.title,
      unit: unit ?? this.unit,
      increment: increment ?? this.increment,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      reminderStartMinutes: reminderStartMinutes ?? this.reminderStartMinutes,
      reminderEndMinutes: reminderEndMinutes ?? this.reminderEndMinutes,
    );
  }

  @override
  List<Object?> get props => [
    type,
    target,
    title,
    unit,
    increment,
    reminderEnabled,
    reminderIntervalMinutes,
    reminderStartMinutes,
    reminderEndMinutes,
  ];
}
