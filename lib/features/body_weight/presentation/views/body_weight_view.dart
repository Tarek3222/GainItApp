import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/trend_chart.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/usecases/body_weight_use_cases.dart';
import '../cubits/body_weight_cubit.dart';
import '../widgets/log_weight_sheet.dart';

class BodyWeightView extends StatelessWidget {
  const BodyWeightView({super.key});

  Future<void> _log(BuildContext context, BodyWeightOverview? overview) async {
    final cubit = context.read<BodyWeightCubit>();
    final kg = await showLogWeightSheet(
      context,
      initialKg: overview?.summary?.latest.weightKg,
    );
    if (kg == null) return;
    final outcome = await cubit.add(kg);
    if (outcome case ActionFailed(:final message) when context.mounted) {
      showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body weight')),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton.extended(
          onPressed: () {
            final state = context.read<BodyWeightCubit>().state;
            _log(
              context,
              state is ViewLoaded<BodyWeightOverview> ? state.data : null,
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Log weight'),
        ),
      ),
      body: ViewStateBuilder<BodyWeightCubit, BodyWeightOverview>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, overview) => overview.isEmpty
            ? const EmptyState(
                icon: Icons.monitor_weight_outlined,
                title: 'No weigh-ins yet',
                message: 'Log your weight to track your trend.',
              )
            : _Body(overview: overview),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.overview});

  final BodyWeightOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final summary = overview.summary!;
    final series = [
      ChartSeries(
        label: 'Weigh-ins',
        color: semantic.mutedText,
        showDots: true,
        dashed: true,
        points: [
          for (final p in overview.points) (date: p.date, value: p.weightKg),
        ],
      ),
      ChartSeries(
        label: '7-day average',
        color: theme.colorScheme.primary,
        showDots: false,
        points: [
          for (final p in overview.trend) (date: p.date, value: p.weightKg),
        ],
      ),
    ];
    return PageBody(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl * 2,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Current'),
              Text(
                Formatters.kg(summary.latest.weightKg),
                style: AppTypography.metricLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (summary.changeOverPeriod != null)
                Text(
                  '${Formatters.signedKg(summary.changeOverPeriod!)} '
                  '/ ${summary.periodDays ~/ 7} wk',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              TrendChart(series: series),
              const SizedBox(height: AppSpacing.sm),
              ChartLegend(series: series),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel('History'),
        for (final entry in overview.entries)
          Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              color: semantic.danger,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) =>
                context.read<BodyWeightCubit>().delete(entry.id),
            child: ListTile(
              title: Text(Formatters.fullDate(entry.measuredAt)),
              trailing: Text(
                Formatters.kg(entry.weightKg),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
