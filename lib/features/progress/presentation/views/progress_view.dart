import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/l10n/enum_labels.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/trend_chart.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/progress_entities.dart';
import '../cubits/progress_cubits.dart';

class ProgressView extends StatelessWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('progress.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'progress.history'.tr(),
            onPressed: () => context.push(RoutePaths.history),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: ViewStateBuilder<ProgressCubit, ProgressDashboard>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, dashboard) => PageBody(
          children: [
            _BodyWeightSection(dashboard: dashboard),
            const SizedBox(height: AppSpacing.md),
            _StrengthSection(exercises: dashboard.exercises),
            const SizedBox(height: AppSpacing.md),
            _VolumeSection(volume: dashboard.weeklyVolume),
          ],
        ),
      ),
    );
  }
}

class _BodyWeightSection extends StatelessWidget {
  const _BodyWeightSection({required this.dashboard});

  final ProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = dashboard.bodyWeight;
    return AppCard(
      onTap: () => context.push(RoutePaths.bodyWeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            'progress.bodyWeight'.tr(),
            trailing: summary == null
                ? null
                : Text(
                    context.units.weight(summary.latest.weightKg),
                    style: theme.textTheme.titleMedium,
                  ),
          ),
          TrendChart(
            height: 160,
            series: [
              ChartSeries(
                color: theme.colorScheme.primary,
                showDots: false,
                points: [
                  for (final p in dashboard.weightTrend)
                    (
                      date: p.date,
                      value: context.units.toDisplayWeight(p.weightKg),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.exercises});

  final List<ExerciseRef> exercises;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('progress.strength'.tr()),
          if (exercises.isEmpty)
            Text(
              'progress.strengthEmpty'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final exercise in exercises)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(seedName(exercise.name)),
              subtitle: Text(exercise.muscle.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.exercise(exercise.id)),
            ),
        ],
      ),
    );
  }
}

class _VolumeSection extends StatelessWidget {
  const _VolumeSection({required this.volume});

  final List<MuscleVolume> volume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('progress.weeklyVolume'.tr()),
          for (final m in volume)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(m.muscle.label)),
                      Text(
                        m.planned == 0
                            ? '${m.done}'
                            : '${m.done} / ${m.planned}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  LinearProgressIndicator(
                    value: m.fraction,
                    minHeight: 5,
                    borderRadius: AppRadius.smAll,
                    color: m.done >= m.planned && m.planned > 0
                        ? semantic.success
                        : theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
