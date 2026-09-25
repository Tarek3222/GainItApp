import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/number_stepper.dart';
import '../../domain/entities/daily_goal_entities.dart';
import 'goal_display.dart';

/// Edits a goal's target and reminders. [onSave] saves it; the sheet stays
/// open with the error when saving fails. Resolves to whether it saved.
Future<bool> showGoalEditorSheet(
  BuildContext context, {
  required GoalInput initial,
  required String title,
  required Future<ActionOutcome<void>> Function(GoalInput input) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        GoalEditorSheet(initial: initial, title: title, onSave: onSave),
  );
  return saved ?? false;
}

class GoalEditorSheet extends StatefulWidget {
  const GoalEditorSheet({
    super.key,
    required this.initial,
    required this.title,
    required this.onSave,
  });

  final GoalInput initial;
  final String title;
  final Future<ActionOutcome<void>> Function(GoalInput input) onSave;

  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  static const _intervals = [30, 60, 90, 120, 180, 240];

  late GoalInput _input;
  late final TextEditingController _name;
  late final TextEditingController _unit;
  String? _error;
  bool _saving = false;

  bool get _isCustom => _input.type == DailyGoalType.custom;

  @override
  void initState() {
    super.initState();
    _input = widget.initial;
    _name = TextEditingController(text: _input.title);
    _unit = TextEditingController(text: _input.unit);
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _update(GoalInput input) => setState(() {
    _input = input;
    _error = null;
  });

  Future<void> _pickTime({required bool start}) async {
    final minutes = start
        ? _input.reminderStartMinutes
        : _input.reminderEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    final value = picked.hour * 60 + picked.minute;
    _update(
      start
          ? _input.copyWith(reminderStartMinutes: value)
          : _input.copyWith(reminderEndMinutes: value),
    );
  }

  Future<void> _save() async {
    final input = _input.copyWith(title: _name.text, unit: _unit.text);
    setState(() => _saving = true);
    final outcome = await widget.onSave(input);
    if (!mounted) return;
    switch (outcome) {
      case ActionDone():
        Navigator.of(context).pop(true);
      case ActionFailed(:final message):
        setState(() {
          _saving = false;
          _error = message;
        });
    }
  }

  Widget _target(UnitFormat units) {
    switch (_input.type) {
      case DailyGoalType.water:
        return NumberStepper(
          label: '${units.waterUnit} per day',
          value: units.toDisplayWater(_input.target),
          step: units.waterTargetStep,
          min: units.waterTargetStep,
          max: units.toDisplayWater(Validators.maxWaterTargetMl),
          decimals: !units.isMetric,
          format: Formatters.weight,
          onChanged: (v) =>
              _update(_input.copyWith(target: units.fromDisplayWater(v))),
        );
      case DailyGoalType.steps:
        return NumberStepper(
          label: 'steps per day',
          value: _input.target,
          step: 500,
          min: 500,
          max: Validators.maxStepTarget,
          onChanged: (v) => _update(_input.copyWith(target: v)),
        );
      case DailyGoalType.custom:
        return NumberStepper(
          label: 'target per day',
          value: _input.target,
          step: 1,
          min: 1,
          max: Validators.maxCustomTarget,
          decimals: true,
          format: Formatters.weight,
          onChanged: (v) => _update(_input.copyWith(target: v)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = context.units;
    final perDay = _input.remindersPerDay;
    final error = _error;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              if (_isCustom) ...[
                TextField(
                  controller: _name,
                  maxLength: Validators.maxGoalTitle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Read, Protein, Stretch',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                TextField(
                  controller: _unit,
                  maxLength: Validators.maxGoalUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit (optional)',
                    hintText: 'e.g. pages, g, min',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _target(units),
              if (_isCustom) ...[
                const SizedBox(height: AppSpacing.sm),
                NumberStepper(
                  label: 'quick add',
                  value: _input.increment,
                  step: 1,
                  min: 1,
                  max: Validators.maxCustomTarget,
                  decimals: true,
                  format: Formatters.weight,
                  onChanged: (v) => _update(_input.copyWith(increment: v)),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me'),
                subtitle: Text(
                  _input.reminderEnabled
                      ? '$perDay reminder${perDay == 1 ? '' : 's'} a day'
                      : 'Notifications during the day',
                ),
                value: _input.reminderEnabled,
                onChanged: (v) => _update(_input.copyWith(reminderEnabled: v)),
              ),
              if (_input.reminderEnabled) ...[
                DropdownButtonFormField<int>(
                  initialValue:
                      _intervals.contains(_input.reminderIntervalMinutes)
                      ? _input.reminderIntervalMinutes
                      : null,
                  decoration: const InputDecoration(labelText: 'Every'),
                  items: [
                    for (final minutes in _intervals)
                      DropdownMenuItem(
                        value: minutes,
                        child: Text(intervalLabel(minutes)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _update(_input.copyWith(reminderIntervalMinutes: v));
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(start: true),
                        child: Text(
                          'From '
                          '${Formatters.timeOfDay(_input.reminderStartMinutes)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(start: false),
                        child: Text(
                          'Until '
                          '${Formatters.timeOfDay(_input.reminderEndMinutes)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.semanticColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
