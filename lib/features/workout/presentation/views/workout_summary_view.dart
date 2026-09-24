import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/training/performance_comparator.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/workout_summary.dart';
import '../cubits/workout_summary_cubit.dart';

class WorkoutSummaryView extends StatelessWidget {
  const WorkoutSummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: BlocBuilder<WorkoutSummaryCubit, WorkoutSummaryState>(
        builder: (context, state) => switch (state) {
          WorkoutSummaryLoading() => const LoadingView(),
          WorkoutSummaryError(:final message) => ErrorView(
            message: message,
            onRetry: context.read<WorkoutSummaryCubit>().load,
          ),
          WorkoutSummaryLoaded(:final summary) => _SummaryBody(
            summary: summary,
          ),
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: PageBody(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: context.semanticColors.success,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Workout Complete',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                summary.workoutName,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              Text(
                '${summary.workingSets} working sets · '
                '${Formatters.duration(summary.duration)}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (summary.volume.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Volume'),
                      for (final entry in summary.volume.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxs,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key.label)),
                              Text(
                                '${entry.value} sets',
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              if (summary.lines.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Progress'),
                      for (final line in summary.lines)
                        ProgressLineTile(line: line),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Finish'),
            ),
          ),
        ),
      ],
    );
  }
}

/// "✓ Bench Press +2 reps" style line. Reused by history session details.
class ProgressLineTile extends StatelessWidget {
  const ProgressLineTile({super.key, required this.line});

  final ExerciseProgressLine line;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final c = line.comparison;
    final (icon, color, text) = switch (c.outcome) {
      ProgressOutcome.weightIncreased => (
        Icons.check_circle,
        semantic.success,
        Formatters.signedKg(c.weightDelta),
      ),
      ProgressOutcome.repsIncreased => (
        Icons.check_circle,
        semantic.success,
        '+${c.repsDelta} rep${c.repsDelta == 1 ? '' : 's'}',
      ),
      ProgressOutcome.maintained => (
        Icons.arrow_forward,
        semantic.mutedText,
        'maintained',
      ),
      ProgressOutcome.regressed => (
        Icons.arrow_downward,
        semantic.warning,
        c.weightDelta < 0
            ? Formatters.signedKg(c.weightDelta)
            : '${c.repsDelta} reps',
      ),
      ProgressOutcome.firstTime => (
        Icons.fiber_new_outlined,
        semantic.mutedText,
        'first time',
      ),
    };
    final current = line.current;
    return InkWell(
      onTap: () => context.push(RoutePaths.exercise(line.exerciseId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.exerciseName),
                  Text(
                    '${Formatters.kg(current.topWeight)} · '
                    '${Formatters.repsList(current.sets.map((s) => s.reps))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(text, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
