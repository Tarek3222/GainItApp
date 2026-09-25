import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';

/// How goals are named, drawn and measured on screen.
extension GoalDisplay on DailyGoal {
  String get displayName => switch (type) {
    DailyGoalType.water => 'Water',
    DailyGoalType.steps => 'Steps',
    DailyGoalType.custom => title,
  };

  IconData get icon => switch (type) {
    DailyGoalType.water => Icons.water_drop_outlined,
    DailyGoalType.steps => Icons.directions_walk,
    DailyGoalType.custom => Icons.flag_outlined,
  };

  /// "1.5 L", "8,432 steps", "20 pages".
  String amountText(UnitFormat units, double amount) => switch (type) {
    DailyGoalType.water => units.water(amount),
    DailyGoalType.steps => '${_count(amount)} steps',
    DailyGoalType.custom => _withUnit(Formatters.weight(amount)),
  };

  /// Today's progress against the target: "1.25 / 3 L",
  /// "8,432 / 10,000 steps", "12 / 20 pages".
  String progressText(UnitFormat units, double amount) => switch (type) {
    DailyGoalType.water => units.waterProgress(amount, target),
    DailyGoalType.steps => '${_count(amount)} / ${_count(target)} steps',
    DailyGoalType.custom => _withUnit(
      '${Formatters.weight(amount)} / ${Formatters.weight(target)}',
    ),
  };

  /// "Every 2 h, 9:00 AM – 9:00 PM", or "Reminders off".
  String get reminderSummary {
    if (!reminderEnabled) return 'Reminders off';
    return 'Every ${intervalLabel(reminderIntervalMinutes)}, '
        '${Formatters.timeOfDay(reminderStartMinutes)} – '
        '${Formatters.timeOfDay(reminderEndMinutes)}';
  }

  String _withUnit(String value) =>
      unit.trim().isEmpty ? value : '$value ${unit.trim()}';

  static String _count(double value) =>
      NumberFormat.decimalPattern().format(value.round());
}

/// "30 min", "1 h", "1.5 h".
String intervalLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  return '${Formatters.weight(minutes / 60)} h';
}
