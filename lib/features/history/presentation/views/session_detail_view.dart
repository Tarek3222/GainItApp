import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/l10n/enum_labels.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/history_entities.dart';
import '../cubits/history_cubits.dart';

class SessionDetailView extends StatelessWidget {
  const SessionDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('history.workout'.tr())),
      body: ViewStateBuilder<SessionDetailCubit, SessionDetail>(
        onRetry: (cubit) => cubit.load(),
        builder: (context, detail) {
          final theme = Theme.of(context);
          return PageBody(
            children: [
              Text(
                seedName(detail.workoutName),
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                [
                  Formatters.fullDate(detail.date),
                  'common.sets'.plural(detail.workingSets),
                  Formatters.duration(detail.duration),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              if (detail.notes != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(detail.notes!),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final exercise in detail.exercises) ...[
                _ExerciseCard(exercise: exercise),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final SessionDetailExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push(RoutePaths.exercise(exercise.exerciseId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seedName(exercise.name),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(exercise.muscle.label, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (exercise.sets.isEmpty)
            Text(
              (exercise.skipped ? 'history.skipped' : 'history.noSets').tr(),
              style: theme.textTheme.bodySmall,
            ),
          for (final set in exercise.sets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      'workout.setN'.tr(namedArgs: {'n': '${set.setNumber}'}),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${context.units.weight(set.actualWeight)} × ${set.actualReps}',
                    ),
                  ),
                  if (set.rir != null)
                    Text(
                      'workout.rir'.tr(namedArgs: {'n': '${set.rir}'}),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
