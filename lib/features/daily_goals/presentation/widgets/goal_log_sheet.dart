import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/number_stepper.dart';
import 'goal_display.dart';

/// Asks how much to add to (or take back from) today's progress. Resolves
/// to the change in storage units — negative when taking back — or `null`
/// when dismissed.
Future<double?> showGoalLogSheet(BuildContext context, DailyGoal goal) =>
    showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalLogSheet(goal: goal, units: context.units),
    );

class _GoalLogSheet extends StatefulWidget {
  const _GoalLogSheet({required this.goal, required this.units});

  final DailyGoal goal;
  final UnitFormat units;

  @override
  State<_GoalLogSheet> createState() => _GoalLogSheetState();
}

class _GoalLogSheetState extends State<_GoalLogSheet> {
  /// In display units.
  late double _value;

  DailyGoal get _goal => widget.goal;
  UnitFormat get _units => widget.units;

  @override
  void initState() {
    super.initState();
    _value = switch (_goal.type) {
      DailyGoalType.water => _units.toDisplayWater(
        _units.waterServingsMl.first,
      ),
      DailyGoalType.steps => 1000,
      DailyGoalType.custom => _goal.increment,
    };
  }

  double get _step => switch (_goal.type) {
    DailyGoalType.water => _units.isMetric ? 50 : 1,
    DailyGoalType.steps => 100,
    DailyGoalType.custom => _goal.increment,
  };

  String get _label => switch (_goal.type) {
    DailyGoalType.water => _units.waterUnit,
    DailyGoalType.steps => 'goals.stepsLabel'.tr(),
    DailyGoalType.custom =>
      _goal.unit.trim().isEmpty ? 'goals.amountLabel'.tr() : _goal.unit,
  };

  double get _stored => _goal.type == DailyGoalType.water
      ? _units.fromDisplayWater(_value)
      : _value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWater = _goal.type == DailyGoalType.water;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_goal.displayName, style: theme.textTheme.titleLarge),
            if (_goal.type == DailyGoalType.steps) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'goals.stepsSheetHint'.tr(),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (isWater) ...[
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final ml in [
                    ..._units.waterServingsMl,
                    _units.waterServingsMl.last * 1.5,
                  ])
                    ChoiceChip(
                      label: Text(_units.water(ml)),
                      selected: _value == _units.toDisplayWater(ml),
                      onSelected: (_) =>
                          setState(() => _value = _units.toDisplayWater(ml)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            NumberStepper(
              label: _label,
              value: _value,
              step: _step,
              min: _step,
              max: 100000,
              decimals: !isWater || !_units.isMetric,
              format: Formatters.weight,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(-_stored),
                    icon: const Icon(Icons.remove),
                    label: Text('goals.takeBack'.tr()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_stored),
                    icon: const Icon(Icons.add),
                    label: Text('goals.add'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
