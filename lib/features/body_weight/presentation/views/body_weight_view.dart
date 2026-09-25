import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
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
      appBar: AppBar(title: Text('bodyWeight.title'.tr())),
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
          label: Text('bodyWeight.log'.tr()),
        ),
      ),
      body: ViewStateBuilder<BodyWeightCubit, BodyWeightOverview>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, overview) => overview.isEmpty
            ? EmptyState(
                icon: Icons.monitor_weight_outlined,
                title: 'bodyWeight.empty'.tr(),
                message: 'bodyWeight.emptyHint'.tr(),
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
    final units = context.units;
    final series = [
      ChartSeries(
        label: 'bodyWeight.weighIns'.tr(),
        color: semantic.mutedText,
        showDots: true,
        dashed: true,
        points: [
          for (final p in overview.points)
            (date: p.date, value: units.toDisplayWeight(p.weightKg)),
        ],
      ),
      ChartSeries(
        label: 'bodyWeight.average'.tr(),
        color: theme.colorScheme.primary,
        showDots: false,
        points: [
          for (final p in overview.trend)
            (date: p.date, value: units.toDisplayWeight(p.weightKg)),
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
              SectionLabel('bodyWeight.current'.tr()),
              Text(
                context.units.weight(summary.latest.weightKg),
                style: AppTypography.metricLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (summary.changeOverPeriod != null)
                Text(
                  'home.weightChange'.tr(
                    namedArgs: {
                      'change': context.units.signedWeight(
                        summary.changeOverPeriod!,
                      ),
                      'weeks': '${summary.periodDays ~/ 7}',
                    },
                  ),
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
        SectionLabel('bodyWeight.history'.tr()),
        for (final entry in overview.entries)
          Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              // Swiping toward the start reveals it at the end, in either
              // reading direction.
              alignment: AlignmentDirectional.centerEnd,
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
              color: semantic.danger,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) =>
                context.read<BodyWeightCubit>().delete(entry.id),
            child: ListTile(
              title: Text(Formatters.fullDate(entry.measuredAt)),
              trailing: Text(
                context.units.weight(entry.weightKg),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
