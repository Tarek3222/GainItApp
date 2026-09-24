import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/progression_engine.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/number_stepper.dart';
import '../../domain/entities/active_workout.dart';

typedef LogSetCallback =
    Future<void> Function(double weight, int reps, int? rir);

/// One exercise in the active workout: target, last result, logged sets and
/// the editor for the next set. Large controls, very little text (spec §16).
class ExercisePanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            // Only the latest set can be undone (keeps set numbers contiguous).
            onUndo: identical(set, exercise.sets.last)
                ? () => onUndoSet(set)
                : null,
          ),
        if (exercise.isSkipped)
          const _InfoBanner(
            icon: Icons.skip_next,
            text: 'Skipped. Tap "Unskip" to log sets for this exercise.',
          )
        else if (exercise.isComplete)
          const _InfoBanner(
            icon: Icons.check_circle,
            text: 'All working sets done.',
            success: true,
          )
        else
          SetEditor(
            key: ValueKey('${snapshot.id}-${exercise.nextSetNumber}'),
            exercise: exercise,
            isResting: isResting,
            onLogSet: onLogSet,
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          child: TextButton.icon(
            onPressed: onToggleSkip,
            icon: Icon(exercise.isSkipped ? Icons.undo : Icons.skip_next),
            label: Text(exercise.isSkipped ? 'Unskip' : 'Skip exercise'),
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
      '${s.targetSets} sets',
      if (s.restSeconds > 0)
        'Rest ${Formatters.rest(s.restSeconds, s.restSeconds)}',
      if (s.supersetGroup != null) 'Superset ${s.supersetGroup}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.exerciseName, style: theme.textTheme.headlineSmall),
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
        ? 'Choose a weight'
        : Formatters.kg(rec.suggestedWeight!);
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
          const SectionLabel('Target'),
          Text(
            '$weightText · ${Formatters.repRange(s.repMin, s.repMax)}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'RIR ${s.rirMin}–${s.rirMax}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(rec.reason, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          Text(
            last == null
                ? 'Last: no previous session'
                : 'Last: ${Formatters.kg(last.topWeight)} · '
                      '${Formatters.repsList(last.sets.map((e) => e.reps))}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _LoggedSetRow extends StatelessWidget {
  const _LoggedSetRow({required this.set, this.onUndo});

  final SetLog set;
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
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Set ${set.setNumber}', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              '${Formatters.kg(set.actualWeight)} × ${set.actualReps}'
              '${set.rir == null ? '' : '  RIR ${set.rir}'}',
              style: theme.textTheme.bodyLarge,
            ),
            if (onUndo != null)
              IconButton(
                tooltip: 'Undo set ${set.setNumber}',
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
    return AppCard(
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set $setNumber of ${s.targetSets}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          NumberStepper(
            label: 'kg',
            value: _weight,
            step: s.weightStep,
            min: Validators.minSetWeightKg,
            max: 1000,
            decimals: true,
            format: Formatters.weight,
            onChanged: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          NumberStepper(
            label: 'reps',
            value: _reps.toDouble(),
            step: 1,
            min: 1,
            max: 200,
            onChanged: (v) => setState(() => _reps = v.round()),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('RIR (optional)', style: theme.textTheme.bodySmall),
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
              'Enter a weight above 0',
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
              widget.isResting ? 'Resting…' : 'Complete set $setNumber',
            ),
          ),
        ],
      ),
    );
  }
}
