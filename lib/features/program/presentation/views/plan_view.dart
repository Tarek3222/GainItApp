import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/training/schedule_resolver.dart';
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
        title: const Text('Plan'),
        actions: [
          IconButton(
            tooltip: 'Exercise library',
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
              'Week ${plan.weekNumber} · ${plan.programName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${plan.completedWorkouts} of ${plan.plannedWorkouts} '
              'workouts done this week',
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
      DayStatus.completed => ('Done', semantic.success, Icons.check_circle),
      DayStatus.today => (
        'Today',
        theme.colorScheme.primary,
        Icons.play_circle_fill,
      ),
      DayStatus.upcoming => ('Upcoming', semantic.mutedText, Icons.schedule),
      DayStatus.missed => ('Missed', semantic.warning, Icons.error_outline),
      DayStatus.rest => ('Rest', semantic.mutedText, Icons.bedtime_outlined),
      DayStatus.beforeStart => (
        'Not started',
        semantic.mutedText,
        Icons.remove_circle_outline,
      ),
    };
    final isWorkout = item.day.isWorkout;
    final subtitle = isWorkout
        ? '${item.exerciseCount} exercises · ${item.totalSets} sets'
              '${item.lastCompletedAt == null ? '' : ' · last ${Formatters.shortDate(item.lastCompletedAt!)}'}'
        : 'Recovery day';

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
                Text(item.day.name, style: theme.textTheme.titleMedium),
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
            tooltip: 'Edit ${item.day.name}',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(RoutePaths.editPlanDay(item.day.id)),
          ),
        ],
      ),
    );
  }
}
