import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../../body_weight/presentation/widgets/log_weight_sheet.dart';
import '../../../daily_goals/presentation/widgets/todays_progress_card.dart';
import '../../domain/entities/home_dashboard.dart';
import '../cubits/home_cubit.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The page scrolls under the navigation bar; PageBody pads for it.
      body: SafeArea(
        bottom: false,
        child: ViewStateBuilder<HomeCubit, HomeDashboard>(
          onRetry: (cubit) => cubit.start(),
          // Daily goals load on their own, so they stay usable.
          errorBuilder: (context, message, retry) => PageBody(
            children: [
              ErrorView(message: message, onRetry: retry),
              const TodaysProgressCard(),
            ],
          ),
          builder: (context, dashboard) => PageBody(
            children: [
              _Greeting(dashboard: dashboard),
              const SizedBox(height: AppSpacing.md),
              _NextWorkoutCard(dashboard: dashboard),
              const SizedBox(height: AppSpacing.md),
              const TodaysProgressCard(),
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
                label: Text('home.workoutHistory'.tr()),
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
    final greeting = 'home.greeting.${dashboard.greeting.name}'.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          dashboard.name.isEmpty
              ? greeting
              : 'home.greetingName'.tr(
                  namedArgs: {'greeting': greeting, 'name': dashboard.name},
                ),
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          'home.weekOf'.tr(
            namedArgs: {
              'week': '${dashboard.weekNumber}',
              'program': seedName(dashboard.programName),
            },
          ),
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
            SectionLabel('home.inProgress'.tr()),
            Text(
              seedName(dashboard.activeWorkoutName ?? ''),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => context.go(RoutePaths.workout(activeId)),
              icon: const Icon(Icons.play_arrow),
              label: Text('home.resume'.tr()),
            ),
          ],
        ),
      );
    }

    final next = dashboard.nextWorkout;
    if (next == null) {
      return AppCard(child: Text('home.noWorkouts'.tr()));
    }
    final when = next.isToday
        ? 'home.today'.tr()
        : '${Formatters.weekday(next.date.weekday)}, '
              '${Formatters.shortDate(next.date)}';
    return AppCard(
      onTap: () => context.push(RoutePaths.planDay(next.dayId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel('home.nextWorkout'.tr()),
          Text(seedName(next.name), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'home.nextDetails'.tr(
              namedArgs: {
                'when': when,
                'exercises': 'common.exercises'.plural(next.exerciseCount),
                'sets': 'common.sets'.plural(next.totalSets),
              },
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : () => _start(next.dayId),
            icon: const Icon(Icons.play_arrow),
            label: Text('home.startWorkout'.tr()),
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
      ActionDone() => 'home.weightSaved'.tr(),
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
                SectionLabel('home.bodyWeight'.tr()),
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
                    'home.weightChange'.tr(
                      namedArgs: {
                        'change': context.units.signedWeight(change),
                        'weeks': '${summary!.periodDays ~/ 7}',
                      },
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'home.logBodyWeight'.tr(),
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
          SectionLabel('home.thisWeek'.tr()),
          Text(
            'home.workoutsDone'.tr(
              namedArgs: {
                'done': '${dashboard.weekCompletedWorkouts}',
                'planned': '$planned',
              },
            ),
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
            'common.workingSets'.plural(dashboard.weekWorkingSets),
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
          SectionLabel('home.lastProgress'.tr()),
          Text(
            seedName(progress.exerciseName),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            previous == null
                ? _describe(context.units, progress.current)
                // The arrow points from old to new in either direction.
                : 'home.progressChange'.tr(
                    namedArgs: {
                      'from': _describe(context.units, previous),
                      'to': _describe(context.units, progress.current),
                    },
                  ),
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
