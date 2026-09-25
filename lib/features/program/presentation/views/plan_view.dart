import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/training/schedule_resolver.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/plan_entities.dart';
import '../cubits/plan_cubits.dart';

class PlanView extends StatelessWidget {
  const PlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('plan.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'plan.exerciseLibrary'.tr(),
            icon: const Icon(Icons.fitness_center),
            onPressed: () => context.push(RoutePaths.exercises),
          ),
        ],
      ),
      body: ViewStateBuilder<PlanCubit, WeeklyPlan>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, plan) => PageBody(
          children: [
            Text(
              'plan.weekOf'.tr(
                namedArgs: {
                  'week': '${plan.weekNumber}',
                  'program': seedName(plan.programName),
                },
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'plan.doneThisWeek'.tr(
                namedArgs: {
                  'done': '${plan.completedWorkouts}',
                  'planned': '${plan.plannedWorkouts}',
                },
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final day in plan.days) ...[
              PlanDayCard(item: day),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class PlanDayCard extends StatelessWidget {
  const PlanDayCard({super.key, required this.item});

  final PlanDay item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final (label, color, icon) = switch (item.status) {
      DayStatus.completed => (
        'plan.status.done'.tr(),
        semantic.success,
        Icons.check_circle,
      ),
      DayStatus.today => (
        'plan.status.today'.tr(),
        theme.colorScheme.primary,
        Icons.play_circle_fill,
      ),
      DayStatus.upcoming => (
        'plan.status.upcoming'.tr(),
        semantic.mutedText,
        Icons.schedule,
      ),
      DayStatus.missed => (
        'plan.status.missed'.tr(),
        semantic.warning,
        Icons.error_outline,
      ),
      DayStatus.rest => (
        'plan.status.rest'.tr(),
        semantic.mutedText,
        Icons.bedtime_outlined,
      ),
      DayStatus.beforeStart => (
        'plan.status.notStarted'.tr(),
        semantic.mutedText,
        Icons.remove_circle_outline,
      ),
    };
    final isWorkout = item.day.isWorkout;
    final subtitle = isWorkout
        ? [
            'common.exercises'.plural(item.exerciseCount),
            'common.sets'.plural(item.totalSets),
            if (item.lastCompletedAt case final last?)
              'plan.lastDone'.tr(
                namedArgs: {'date': Formatters.shortDate(last)},
              ),
          ].join(' · ')
        : 'plan.recoveryDay'.tr();

    return AppCard(
      // Rest days have nothing to preview, so they open the editor.
      onTap: () => context.push(
        isWorkout
            ? RoutePaths.planDay(item.day.id)
            : RoutePaths.editPlanDay(item.day.id),
      ),
      borderColor: item.status == DayStatus.today ? color : null,
      color: isWorkout ? null : theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  Formatters.weekdayShort(item.day.weekday).toUpperCase(),
                  style: theme.textTheme.labelMedium,
                ),
                Text('${item.date.day}', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seedName(item.day.name),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            children: [
              Icon(icon, color: color),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
          IconButton(
            tooltip: 'plan.editDay'.tr(
              namedArgs: {'day': seedName(item.day.name)},
            ),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(RoutePaths.editPlanDay(item.day.id)),
          ),
        ],
      ),
    );
  }
}
