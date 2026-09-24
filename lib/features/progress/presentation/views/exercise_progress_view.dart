import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/trend_chart.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/progress_entities.dart';
import '../cubits/progress_cubits.dart';

enum _Metric { oneRepMax, topWeight, reps, volume }

class ExerciseProgressView extends StatelessWidget {
  const ExerciseProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            BlocSelector<
              ExerciseProgressCubit,
              ViewState<ExerciseProgress>,
              String
            >(
              selector: (state) => state is ViewLoaded<ExerciseProgress>
                  ? state.data.exercise.name
                  : '',
              builder: (_, name) => Text(name),
            ),
      ),
      body: ViewStateBuilder<ExerciseProgressCubit, ExerciseProgress>(
        onRetry: (cubit) => cubit.load(),
        builder: (context, progress) => progress.isEmpty
            ? const EmptyState(
                icon: Icons.show_chart,
                title: 'No history yet',
                message: 'Complete this exercise in a workout to see progress.',
              )
            : _Body(progress: progress),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.progress});

  final ExerciseProgress progress;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  _Metric _metric = _Metric.oneRepMax;

  double _value(UnitFormat units, ExerciseTrendPoint p) => switch (_metric) {
    _Metric.oneRepMax => units.toDisplayWeight(p.estimatedOneRepMax),
    _Metric.topWeight => units.toDisplayWeight(p.topWeight),
    _Metric.reps => p.totalReps.toDouble(),
    _Metric.volume => units.toDisplayWeight(p.volumeLoad),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.progress;
    return PageBody(
      children: [
        Text(progress.exercise.muscle.label, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _Stat(
              label: 'Best weight',
              value: context.units.weight(progress.bestWeight!),
            ),
            const SizedBox(width: AppSpacing.sm),
            _Stat(label: 'Best reps', value: '${progress.bestReps}'),
            const SizedBox(width: AppSpacing.sm),
            _Stat(
              label: 'Est. 1RM',
              value: context.units.weight(progress.bestOneRepMax!),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_Metric>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Metric.oneRepMax, label: Text('1RM')),
                  ButtonSegment(value: _Metric.topWeight, label: Text('Load')),
                  ButtonSegment(value: _Metric.reps, label: Text('Reps')),
                  ButtonSegment(value: _Metric.volume, label: Text('Volume')),
                ],
                selected: {_metric},
                onSelectionChanged: (s) => setState(() => _metric = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TrendChart(
                valueFormat: _metric == _Metric.reps
                    ? (v) => v.toStringAsFixed(0)
                    : Formatters.weight,
                series: [
                  ChartSeries(
                    color: theme.colorScheme.primary,
                    points: [
                      for (final p in progress.trend)
                        (date: p.date, value: _value(context.units, p)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel('Recent sessions'),
        for (final session in progress.sessions.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Formatters.fullDate(session.date)),
            trailing: Text(
              '${context.units.weight(session.topWeight)} · '
              '${Formatters.repsList(session.sets.map((s) => s.reps))}',
              style: theme.textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: AppTypography.metricMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.semanticColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
