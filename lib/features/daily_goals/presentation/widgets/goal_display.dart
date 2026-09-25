import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';

/// How goals are named, drawn and measured on screen.
extension GoalDisplay on DailyGoal {
  String get displayName => switch (type) {
    DailyGoalType.water => 'goals.water'.tr(),
    DailyGoalType.steps => 'goals.steps'.tr(),
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
    DailyGoalType.steps => 'goals.stepsCount'.tr(
      namedArgs: {'count': _count(amount)},
    ),
    DailyGoalType.custom => _withUnit(Formatters.weight(amount)),
  };

  /// Today's progress against the target: "1.25 / 3 L",
  /// "8,432 / 10,000 steps", "12 / 20 pages".
  String progressText(UnitFormat units, double amount) => switch (type) {
    DailyGoalType.water => units.waterProgress(amount, target),
    DailyGoalType.steps => 'goals.stepsProgress'.tr(
      namedArgs: {'done': _count(amount), 'target': _count(target)},
    ),
    DailyGoalType.custom => _withUnit(
      '${Formatters.weight(amount)} / ${Formatters.weight(target)}',
    ),
  };

  /// "Every 2 h, 9:00 AM – 9:00 PM", or "Reminders off".
  String get reminderSummary {
    if (!reminderEnabled) return 'goals.remindersOff'.tr();
    return 'goals.reminderSummary'.tr(
      namedArgs: {
        'interval': intervalLabel(reminderIntervalMinutes),
        'from': Formatters.timeOfDay(reminderStartMinutes),
        'to': Formatters.timeOfDay(reminderEndMinutes),
      },
    );
  }

  String _withUnit(String value) =>
      unit.trim().isEmpty ? value : '$value ${unit.trim()}';

  // Western digits and separators in every language, like other numbers.
  static String _count(double value) =>
      NumberFormat.decimalPattern('en').format(value.round());
}

/// "30 min", "1 h", "1.5 h".
String intervalLabel(int minutes) {
  if (minutes < 60) return 'goals.minutes'.tr(namedArgs: {'n': '$minutes'});
  return 'goals.hours'.tr(namedArgs: {'n': Formatters.weight(minutes / 60)});
}
