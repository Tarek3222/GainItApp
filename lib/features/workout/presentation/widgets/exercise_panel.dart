import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/progression_engine.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/l10n/enum_labels.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/number_stepper.dart';
import '../../domain/entities/active_workout.dart';

typedef LogSetCallback =
    Future<void> Function(double weight, int reps, int? rir);

/// One exercise in the active workout: target, last result, logged sets and
/// the editor for the next set. Large controls, very little text (spec §16).
class ExercisePanel extends StatefulWidget {
  const ExercisePanel({
    super.key,
    required this.exercise,
    required this.onLogSet,
    required this.onUndoSet,
    required this.onToggleSkip,
    this.isResting = false,
  });

  final ActiveExercise exercise;

  /// While the rest timer runs the next set cannot be completed.
  final bool isResting;
  final LogSetCallback onLogSet;
  final ValueChanged<SetLog> onUndoSet;
  final VoidCallback onToggleSkip;

  @override
  State<ExercisePanel> createState() => _ExercisePanelState();
}

class _ExercisePanelState extends State<ExercisePanel> {
  /// Sets already logged when the panel appeared. Only sets logged since
  /// then pop in, not every set each time the exercise is swiped back to.
  late final Set<String> _loggedBefore = {
    for (final set in widget.exercise.sets) set.id,
  };

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final snapshot = exercise.snapshot;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        _Header(exercise: exercise),
        const SizedBox(height: AppSpacing.md),
        _TargetCard(exercise: exercise),
        const SizedBox(height: AppSpacing.md),
        for (final set in exercise.sets)
          _LoggedSetRow(
            set: set,
            justLogged: !_loggedBefore.contains(set.id),
            // Only the latest set can be undone (keeps set numbers contiguous).
            onUndo: identical(set, exercise.sets.last)
                ? () => widget.onUndoSet(set)
                : null,
          ),
        if (exercise.isSkipped)
          _InfoBanner(icon: Icons.skip_next, text: 'workout.skippedBanner'.tr())
        else if (exercise.isComplete)
          _InfoBanner(
            icon: Icons.check_circle,
            text: 'workout.allSetsDone'.tr(),
            success: true,
          )
        else
          SetEditor(
            key: ValueKey('${snapshot.id}-${exercise.nextSetNumber}'),
            exercise: exercise,
            isResting: widget.isResting,
            onLogSet: widget.onLogSet,
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          child: TextButton.icon(
            onPressed: widget.onToggleSkip,
            icon: Icon(exercise.isSkipped ? Icons.undo : Icons.skip_next),
            label: Text(
              (exercise.isSkipped ? 'workout.unskip' : 'workout.skipExercise')
                  .tr(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exercise});

  final ActiveExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = exercise.snapshot;
    final details = [
      s.primaryMuscle.label,
      'common.sets'.plural(s.targetSets),
      if (s.restSeconds > 0)
        'workout.rest'.tr(
          namedArgs: {'time': Formatters.rest(s.restSeconds, s.restSeconds)},
        ),
      if (s.supersetGroup case final group?)
        'workout.superset'.tr(namedArgs: {'n': '$group'}),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(seedName(s.exerciseName), style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(details, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.exercise});

  final ActiveExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final rec = exercise.recommendation;
    final s = exercise.snapshot;
    final last = exercise.lastPerformance;
    final weightText = rec.suggestedWeight == null
        ? 'workout.chooseWeight'.tr()
        : context.units.weight(rec.suggestedWeight!);
    final (icon, color) = switch (rec.type) {
      RecommendationType.increaseWeight => (
        Icons.trending_up,
        context.semanticColors.success,
      ),
      RecommendationType.deload => (
        Icons.trending_down,
        context.semanticColors.warning,
      ),
      RecommendationType.addReps => (Icons.add_circle_outline, muted),
      RecommendationType.firstSession => (Icons.flag_outlined, muted),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('workout.target'.tr()),
          Text(
            '$weightText · ${Formatters.repRange(s.repMin, s.repMax)}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'workout.rirRange'.tr(
              namedArgs: {'min': '${s.rirMin}', 'max': '${s.rirMax}'},
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(_adviceText(rec), style: theme.textTheme.bodySmall),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          Text(
            last == null
                ? 'workout.lastNone'.tr()
                : 'workout.last'.tr(
                    namedArgs: {
                      'result':
                          '${context.units.weight(last.topWeight)} · '
                          '${Formatters.repsList(last.sets.map((e) => e.reps))}',
                    },
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// The engine's advice in words.
String _adviceText(Recommendation rec) => switch (rec.type) {
  RecommendationType.firstSession => 'workout.advice.firstSession'.tr(
    namedArgs: {'min': '${rec.repMin}', 'max': '${rec.repMax}'},
  ),
  RecommendationType.increaseWeight => 'workout.advice.increaseWeight'.tr(
    namedArgs: {'max': '${rec.repMax}'},
  ),
  RecommendationType.deload => 'workout.advice.deload'.tr(
    namedArgs: {'count': '${rec.sessionsWithoutProgress}'},
  ),
  RecommendationType.addReps => 'workout.advice.addReps'.tr(
    namedArgs: {'target': '${rec.targetReps ?? rec.repMin}'},
  ),
};

class _LoggedSetRow extends StatelessWidget {
  const _LoggedSetRow({
    required this.set,
    required this.justLogged,
    this.onUndo,
  });

  final SetLog set;

  /// Pops the check in, marking the set that was just completed.
  final bool justLogged;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: context.semanticColors.success,
              size: 20,
            ).pop(context, enabled: justLogged),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'workout.setN'.tr(namedArgs: {'n': '${set.setNumber}'}),
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            Text(
              '${context.units.weight(set.actualWeight)} × ${set.actualReps}'
              '${set.rir == null ? '' : '  ${'workout.rir'.tr(namedArgs: {'n': '${set.rir}'})}'}',
              style: theme.textTheme.bodyLarge,
            ),
            if (onUndo != null)
              IconButton(
                tooltip: 'workout.undoSet'.tr(
                  namedArgs: {'n': '${set.setNumber}'},
                ),
                onPressed: onUndo,
                icon: const Icon(Icons.undo, size: 20),
              )
            else
              const SizedBox(width: AppSpacing.minTouchTarget),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.success = false,
  });

  final IconData icon;
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? context.semanticColors.success
        : context.semanticColors.mutedText;
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Editor for the next set. Draft values are local UI state; nothing is
/// persisted until the user completes the set.
class SetEditor extends StatefulWidget {
  const SetEditor({
    super.key,
    required this.exercise,
    required this.onLogSet,
    this.isResting = false,
  });

  final ActiveExercise exercise;
  final LogSetCallback onLogSet;
  final bool isResting;

  @override
  State<SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<SetEditor> {
  late double _weight;
  late int _reps;
  int? _rir;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weight = widget.exercise.suggestedWeight ?? 0;
    _reps = widget.exercise.suggestedReps;
    _rir = widget.exercise.sets.isEmpty ? null : widget.exercise.sets.last.rir;
  }

  bool get _canComplete => !_saving && !widget.isResting && _weight > 0;

  Future<void> _submit() async {
    if (!_canComplete) return;
    setState(() => _saving = true);
    await widget.onLogSet(_weight, _reps, _rir);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.exercise.snapshot;
    final setNumber = widget.exercise.nextSetNumber;
    final units = context.units;
    return AppCard(
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'workout.setOf'.tr(
              namedArgs: {'n': '$setNumber', 'total': '${s.targetSets}'},
            ),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          // Edited in the display unit (1 lb steps in imperial), stored in kg.
          NumberStepper(
            label: units.weightUnit,
            value: units.toDisplayWeight(_weight),
            step: units.isMetric ? s.weightStep : 1,
            min: units.isMetric ? Validators.minSetWeightKg : 1,
            max: units.toDisplayWeight(Validators.maxWeightKg),
            decimals: true,
            format: units.formatDisplay,
            onChanged: (v) =>
                setState(() => _weight = units.fromDisplayWeight(v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          NumberStepper(
            label: 'workout.repsLabel'.tr(),
            value: _reps.toDouble(),
            step: 1,
            min: 1,
            max: 200,
            onChanged: (v) => setState(() => _reps = v.round()),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('workout.rirOptional'.tr(), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var rir = 0; rir <= 4; rir++)
                ChoiceChip(
                  label: Text(rir == 4 ? '4+' : '$rir'),
                  selected: _rir == rir,
                  onSelected: (selected) =>
                      setState(() => _rir = selected ? rir : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_weight <= 0 && !widget.isResting) ...[
            Text(
              'workout.weightAboveZero'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          FilledButton.icon(
            onPressed: _canComplete ? _submit : null,
            icon: Icon(widget.isResting ? Icons.timer_outlined : Icons.check),
            label: Text(
              widget.isResting
                  ? 'workout.resting'.tr()
                  : 'workout.completeSet'.tr(namedArgs: {'n': '$setNumber'}),
            ),
          ),
        ],
      ),
    );
  }
}
