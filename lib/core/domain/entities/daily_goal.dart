import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Something to reach every day: 3 L of water, 10,000 steps, or a custom
/// target such as "Read 20 pages".
class DailyGoal extends Equatable {
  const DailyGoal({
    required this.id,
    required this.type,
    required this.target,
    required this.sortOrder,
    required this.createdAt,
    this.title = '',
    this.unit = '',
    this.increment = 1,
    this.reminderEnabled = false,
    this.reminderIntervalMinutes = 120,
    this.reminderStartMinutes = 9 * 60,
    this.reminderEndMinutes = 21 * 60,
  });

  final String id;
  final DailyGoalType type;

  /// Water in ml, steps in steps, custom goals in [unit].
  final double target;
  final int sortOrder;
  final DateTime createdAt;

  /// Name of a custom goal. Water and steps are named by their type.
  final String title;

  /// Unit label of a custom goal ("pages", "g").
  final String unit;

  /// What one tap on a custom goal's quick-add button adds.
  final double increment;

  final bool reminderEnabled;

  /// Minutes between two reminders.
  final int reminderIntervalMinutes;

  /// First and last reminder of the day, as minutes after midnight.
  final int reminderStartMinutes;
  final int reminderEndMinutes;

  /// Local times of the day's reminders, in minutes after midnight.
  List<int> get reminderTimes => [
    if (reminderEnabled && reminderIntervalMinutes > 0)
      for (
        var minutes = reminderStartMinutes;
        minutes <= reminderEndMinutes;
        minutes += reminderIntervalMinutes
      )
        minutes,
  ];

  DailyGoal copyWith({
    double? target,
    int? sortOrder,
    String? title,
    String? unit,
    double? increment,
    bool? reminderEnabled,
    int? reminderIntervalMinutes,
    int? reminderStartMinutes,
    int? reminderEndMinutes,
  }) {
    return DailyGoal(
      id: id,
      type: type,
      target: target ?? this.target,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
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
    id,
    type,
    target,
    sortOrder,
    createdAt,
    title,
    unit,
    increment,
    reminderEnabled,
    reminderIntervalMinutes,
    reminderStartMinutes,
    reminderEndMinutes,
  ];
}

/// A change to a day's progress: the new [total] and how much was really
/// [applied] (less than asked when taking back more than was logged).
typedef ProgressChange = ({double total, double applied});

/// Progress logged on one goal for one day (one record per goal per day).
/// For steps it holds only steps added by hand; the sensor adds the rest.
class DailyGoalLog extends Equatable {
  const DailyGoalLog({
    required this.id,
    required this.goalId,
    required this.dayKey,
    required this.amount,
    required this.updatedAt,
  });

  final String id;
  final String goalId;

  /// Calendar day the progress belongs to, as `yyyymmdd` (see `dayKeyOf`).
  final int dayKey;
  final double amount;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, goalId, dayKey, amount, updatedAt];
}
