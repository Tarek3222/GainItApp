import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/l10n/enum_labels.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/muscle_chips.dart';
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
                  ? seedName(state.data.day.name)
                  : '',
              builder: (_, title) => Text(title),
            ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'overview.editWorkout'.tr(),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(
                RoutePaths.editPlanDay(
                  context.read<WorkoutOverviewCubit>().dayId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ViewStateBuilder<WorkoutOverviewCubit, WorkoutOverview>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, overview) {
          final canTrain =
              overview.day.isWorkout && overview.exercises.isNotEmpty;
          Widget edit(String label) => FilledButton.icon(
            onPressed: () =>
                context.push(RoutePaths.editPlanDay(overview.day.id)),
            icon: const Icon(Icons.edit_outlined),
            label: Text(label),
          );
          return Column(
            children: [
              Expanded(
                // The start button below already keeps clear of the bar.
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: canTrain || overview.isInProgress,
                  child: switch (overview) {
                    WorkoutOverview(day: WorkoutDay(isWorkout: false)) =>
                      EmptyState(
                        icon: Icons.bedtime_outlined,
                        title: 'overview.restDay'.tr(),
                        message: 'overview.restDayHint'.tr(),
                        action: edit('overview.editDay'.tr()),
                      ),
                    WorkoutOverview(exercises: []) => EmptyState(
                      icon: Icons.playlist_add,
                      title: 'overview.noExercises'.tr(),
                      message: 'overview.noExercisesHint'.tr(),
                      action: edit('overview.editWorkout'.tr()),
                    ),
                    _ => _OverviewList(overview: overview),
                  },
                ),
              ),
              // An in-progress workout can always be resumed, even if the
              // day was edited meanwhile.
              if (canTrain || overview.isInProgress)
                _StartButton(inProgress: overview.isInProgress),
            ],
          );
        },
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
          [
            Formatters.weekday(overview.day.weekday),
            'common.exercises'.plural(overview.exercises.length),
            'common.workingSets'.plural(overview.totalSets),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (overview.lastCompletedAt != null)
          Text(
            'overview.lastDone'.tr(
              namedArgs: {
                'date': Formatters.fullDate(overview.lastCompletedAt!),
              },
            ),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel('common.targetMuscles'.tr()),
        MuscleChips(
          primary: overview.targetMuscles,
          secondary: overview.assistingMuscles,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'overview.volume'.tr(
            namedArgs: {
              'list': [
                for (final m in overview.targetMuscles)
                  '${m.label} ${overview.plannedVolume[m]}',
              ].join(' · '),
            },
          ),
          style: theme.textTheme.bodySmall,
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
                  '${index + 1}. ${seedName(exercise.name)}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (c.supersetGroup != null)
                Chip(
                  label: Text(
                    'workout.superset'.tr(
                      namedArgs: {'n': '${c.supersetGroup}'},
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          MuscleChips(
            primary: [exercise.primaryMuscle],
            secondary: exercise.secondaryMuscles,
            dense: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'overview.configLine'.tr(
              namedArgs: {
                'sets': '${c.workingSets}',
                'reps': Formatters.repRange(c.repMin, c.repMax),
                'rirMin': '${c.rirMin}',
                'rirMax': '${c.rirMax}',
                'rest': Formatters.rest(c.restMinSeconds, c.restMaxSeconds),
              },
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            rec.suggestedWeight == null
                ? 'overview.targetFirst'.tr()
                : 'overview.target'.tr(
                    namedArgs: {
                      'weight': context.units.weight(rec.suggestedWeight!),
                    },
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (last != null)
            Text(
              'workout.last'.tr(
                namedArgs: {
                  'result':
                      '${context.units.weight(last.topWeight)} · '
                      '${Formatters.repsList(last.sets.map((s) => s.reps))}',
                },
              ),
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
          label: Text(
            (widget.inProgress ? 'overview.resume' : 'overview.start').tr(),
          ),
        ),
      ),
    );
  }
}
