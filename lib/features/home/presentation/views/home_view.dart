import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../../body_weight/presentation/widgets/log_weight_sheet.dart';
import '../../domain/entities/home_dashboard.dart';
import '../cubits/home_cubit.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ViewStateBuilder<HomeCubit, HomeDashboard>(
          onRetry: (cubit) => cubit.start(),
          builder: (context, dashboard) => PageBody(
            children: [
              _Greeting(dashboard: dashboard),
              const SizedBox(height: AppSpacing.md),
              _NextWorkoutCard(dashboard: dashboard),
              const SizedBox(height: AppSpacing.md),
              _BodyWeightCard(dashboard: dashboard),
              const SizedBox(height: AppSpacing.md),
              _ThisWeekCard(dashboard: dashboard),
              if (dashboard.lastProgress != null) ...[
                const SizedBox(height: AppSpacing.md),
                _LastProgressCard(progress: dashboard.lastProgress!),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.history),
                icon: const Icon(Icons.history),
                label: const Text('Workout history'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = dashboard.name.isEmpty ? '' : ', ${dashboard.name}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${dashboard.greeting}$name',
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          'Week ${dashboard.weekNumber} · ${dashboard.programName}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NextWorkoutCard extends StatefulWidget {
  const _NextWorkoutCard({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  State<_NextWorkoutCard> createState() => _NextWorkoutCardState();
}

class _NextWorkoutCardState extends State<_NextWorkoutCard> {
  bool _busy = false;

  Future<void> _start(String dayId) async {
    setState(() => _busy = true);
    final outcome = await context.read<HomeCubit>().startWorkout(dayId);
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
    final theme = Theme.of(context);
    final dashboard = widget.dashboard;
    final activeId = dashboard.activeSessionId;

    if (activeId != null) {
      return AppCard(
        borderColor: theme.colorScheme.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Workout in progress'),
            Text(
              dashboard.activeWorkoutName ?? '',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => context.go(RoutePaths.workout(activeId)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume workout'),
            ),
          ],
        ),
      );
    }

    final next = dashboard.nextWorkout;
    if (next == null) {
      return const AppCard(child: Text('No workouts scheduled.'));
    }
    final when = next.isToday
        ? 'Today'
        : '${Formatters.weekday(next.date.weekday)}, '
              '${Formatters.shortDate(next.date)}';
    return AppCard(
      onTap: () => context.push(RoutePaths.planDay(next.dayId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Next workout'),
          Text(next.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$when · ${next.exerciseCount} exercises · ${next.totalSets} sets',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : () => _start(next.dayId),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start workout'),
          ),
        ],
      ),
    );
  }
}

class _BodyWeightCard extends StatelessWidget {
  const _BodyWeightCard({required this.dashboard});

  final HomeDashboard dashboard;

  Future<void> _log(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    final kg = await showLogWeightSheet(
      context,
      initialKg: dashboard.bodyWeight?.latest.weightKg,
    );
    if (kg == null) return;
    final outcome = await cubit.logBodyWeight(kg);
    if (!context.mounted) return;
    showMessage(context, switch (outcome) {
      ActionDone() => 'Weight saved.',
      ActionFailed(:final message) => message,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = dashboard.bodyWeight;
    final change = summary?.changeOverPeriod;
    return AppCard(
      onTap: () => context.push(RoutePaths.bodyWeight),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Body weight'),
                Text(
                  summary == null
                      ? '—'
                      : context.units.weight(summary.latest.weightKg),
                  style: AppTypography.metricMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (change != null)
                  Text(
                    '${context.units.signedWeight(change)} / '
                    '${summary!.periodDays ~/ 7} wk',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Log body weight',
            onPressed: () => _log(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = dashboard.weekPlannedWorkouts;
    return AppCard(
      onTap: () => context.go(RoutePaths.plan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('This week'),
          Text(
            '${dashboard.weekCompletedWorkouts}/$planned workouts',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: planned == 0 ? 0 : dashboard.weekCompletedWorkouts / planned,
            minHeight: 6,
            borderRadius: AppRadius.smAll,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${dashboard.weekWorkingSets} working sets',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LastProgressCard extends StatelessWidget {
  const _LastProgressCard({required this.progress});

  final HomeProgress progress;

  static String _describe(UnitFormat units, ExerciseSessionPerformance p) =>
      '${units.weight(p.topWeight)} '
      '${Formatters.repsList(p.sets.map((s) => s.reps))}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previous = progress.previous;
    return AppCard(
      onTap: () => context.push(RoutePaths.exercise(progress.exerciseId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Last progress'),
          Text(progress.exerciseName, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            previous == null
                ? _describe(context.units, progress.current)
                : '${_describe(context.units, previous)} → '
                      '${_describe(context.units, progress.current)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: progress.comparison.isImprovement
                  ? context.semanticColors.success
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
