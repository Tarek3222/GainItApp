import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/plan_entities.dart';
import '../cubits/plan_cubits.dart';

class WorkoutOverviewView extends StatelessWidget {
  const WorkoutOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            BlocSelector<
              WorkoutOverviewCubit,
              ViewState<WorkoutOverview>,
              String
            >(
              selector: (state) => state is ViewLoaded<WorkoutOverview>
                  ? state.data.day.name
                  : '',
              builder: (_, title) => Text(title),
            ),
      ),
      body: ViewStateBuilder<WorkoutOverviewCubit, WorkoutOverview>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, overview) => Column(
          children: [
            Expanded(child: _OverviewList(overview: overview)),
            _StartButton(inProgress: overview.isInProgress),
          ],
        ),
      ),
    );
  }
}

class _OverviewList extends StatelessWidget {
  const _OverviewList({required this.overview});

  final WorkoutOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageBody(
      children: [
        Text(
          '${Formatters.weekday(overview.day.weekday)} · '
          '${overview.exercises.length} exercises · '
          '${overview.totalSets} working sets',
          style: theme.textTheme.bodySmall,
        ),
        if (overview.lastCompletedAt != null)
          Text(
            'Last done ${Formatters.fullDate(overview.lastCompletedAt!)}',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final entry in overview.plannedVolume.entries)
              Chip(label: Text('${entry.key.label} ${entry.value}')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final (index, exercise) in overview.exercises.indexed) ...[
          _ExerciseTile(index: index, exercise: exercise),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.index, required this.exercise});

  final int index;
  final OverviewExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final c = exercise.config;
    final rec = exercise.recommendation;
    final last = exercise.lastPerformance;
    return AppCard(
      onTap: () => context.push(RoutePaths.exercise(exercise.exerciseId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${exercise.name}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (c.supersetGroup != null)
                Chip(
                  label: Text('Superset ${c.supersetGroup}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${c.workingSets} × ${Formatters.repRange(c.repMin, c.repMax)} · '
            'RIR ${c.rirMin}–${c.rirMax} · '
            'Rest ${Formatters.rest(c.restMinSeconds, c.restMaxSeconds)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            rec.suggestedWeight == null
                ? 'Target: first session — find your working weight'
                : 'Target: ${Formatters.kg(rec.suggestedWeight!)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (last != null)
            Text(
              'Last: ${Formatters.kg(last.topWeight)} · '
              '${Formatters.repsList(last.sets.map((s) => s.reps))}',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          if (c.notes != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(c.notes!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _StartButton extends StatefulWidget {
  const _StartButton({required this.inProgress});

  final bool inProgress;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    final outcome = await context.read<WorkoutOverviewCubit>().startWorkout();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case ActionDone(:final value):
        context.go(RoutePaths.workout(value));
      case ActionFailed(:final message):
        showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(widget.inProgress ? 'Resume workout' : 'Start workout'),
        ),
      ),
    );
  }
}
