import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/number_stepper.dart';

/// Edits how an exercise is done on a plan day. Pops with the updated entry,
/// or `null` when cancelled.
Future<ProgramExercise?> showExerciseConfigSheet(
  BuildContext context, {
  required ProgramExercise entry,
  required String exerciseName,
}) {
  return showModalBottomSheet<ProgramExercise>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ExerciseConfigSheet(entry: entry, exerciseName: exerciseName),
  );
}

class _ExerciseConfigSheet extends StatefulWidget {
  const _ExerciseConfigSheet({required this.entry, required this.exerciseName});

  final ProgramExercise entry;
  final String exerciseName;

  @override
  State<_ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<_ExerciseConfigSheet> {
  late final TextEditingController _notes;
  late int _sets;
  late int _repMin;
  late int _repMax;
  late int _restMin;
  late int _restMax;
  late int _rirMin;
  late int _rirMax;
  late double _step;
  int? _superset;

  static const _restStep = 15;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _notes = TextEditingController(text: e.notes ?? '');
    _sets = e.workingSets;
    _repMin = e.repMin;
    _repMax = e.repMax;
    _restMin = e.restMinSeconds;
    _restMax = e.restMaxSeconds;
    _rirMin = e.rirMin;
    _rirMax = e.rirMax;
    _step = e.weightStep;
    _superset = e.supersetGroup;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final notes = _notes.text.trim();
    Navigator.pop(
      context,
      widget.entry.copyWith(
        workingSets: _sets,
        repMin: _repMin,
        repMax: _repMax,
        restMinSeconds: _restMin,
        restMaxSeconds: _restMax,
        rirMin: _rirMin,
        rirMax: _rirMax,
        weightStep: _step,
        supersetGroup: _superset,
        clearSuperset: _superset == null,
        notes: notes,
        clearNotes: notes.isEmpty,
      ),
    );
  }

  /// A labelled pair of steppers where min can never pass max.
  Widget _range({
    required String title,
    required String unit,
    required int min,
    required int max,
    required int step,
    required int lowest,
    required int highest,
    required ValueChanged<(int, int)> onChanged,
    String Function(double)? format,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        Row(
          children: [
            Expanded(
              child: NumberStepper(
                label: 'config.min'.tr(namedArgs: {'unit': unit}),
                value: min.toDouble(),
                step: step.toDouble(),
                min: lowest.toDouble(),
                max: highest.toDouble(),
                format: format,
                onChanged: (v) {
                  final value = v.round();
                  onChanged((value, value > max ? value : max));
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: NumberStepper(
                label: 'config.max'.tr(namedArgs: {'unit': unit}),
                value: max.toDouble(),
                step: step.toDouble(),
                min: lowest.toDouble(),
                max: highest.toDouble(),
                format: format,
                onChanged: (v) {
                  final value = v.round();
                  onChanged((value < min ? value : min, value));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(widget.exerciseName, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          SectionLabel('config.workingSets'.tr()),
          NumberStepper(
            label: 'config.setsUnit'.tr(),
            value: _sets.toDouble(),
            step: 1,
            min: 1,
            max: Validators.maxSets.toDouble(),
            onChanged: (v) => setState(() => _sets = v.round()),
          ),
          const SizedBox(height: AppSpacing.md),
          _range(
            title: 'config.repRange'.tr(),
            unit: 'workout.repsLabel'.tr(),
            min: _repMin,
            max: _repMax,
            step: 1,
            lowest: 1,
            highest: Validators.maxReps,
            onChanged: (r) => setState(() {
              _repMin = r.$1;
              _repMax = r.$2;
            }),
          ),
          _range(
            title: 'config.rest'.tr(),
            unit: 'config.restUnit'.tr(),
            min: _restMin,
            max: _restMax,
            step: _restStep,
            lowest: 0,
            highest: Validators.maxRestSeconds,
            format: (v) => Formatters.rest(v.round(), v.round()),
            onChanged: (r) => setState(() {
              _restMin = r.$1;
              _restMax = r.$2;
            }),
          ),
          _range(
            title: 'config.rir'.tr(),
            unit: 'RIR',
            min: _rirMin,
            max: _rirMax,
            step: 1,
            lowest: 0,
            highest: Validators.maxRir,
            onChanged: (r) => setState(() {
              _rirMin = r.$1;
              _rirMax = r.$2;
            }),
          ),
          SectionLabel('config.weightStep'.tr()),
          NumberStepper(
            label: 'units.kg'.tr(),
            value: _step,
            step: 0.5,
            min: 0.5,
            max: Validators.maxWeightStepKg,
            decimals: true,
            // Stored in kg; imperial users also see the pound equivalent.
            format: context.units.isMetric
                ? Formatters.weight
                : (v) => '${Formatters.weight(v)} ≈ ${context.units.weight(v)}',
            onChanged: (v) => setState(() => _step = v),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int?>(
            initialValue: _superset,
            decoration: InputDecoration(labelText: 'config.superset'.tr()),
            items: [
              DropdownMenuItem(value: null, child: Text('config.none'.tr())),
              for (var group = 1; group <= Validators.maxSupersetGroup; group++)
                DropdownMenuItem(
                  value: group,
                  child: Text(
                    'workout.superset'.tr(namedArgs: {'n': '$group'}),
                  ),
                ),
            ],
            onChanged: (g) => setState(() => _superset = g),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            maxLength: Validators.maxNotes,
            decoration: InputDecoration(labelText: 'config.notes'.tr()),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: _save, child: Text('common.save'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }
}
