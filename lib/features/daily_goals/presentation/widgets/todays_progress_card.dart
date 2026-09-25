import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/services/step_counter.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/daily_goal_entities.dart';
import '../cubits/daily_goal_cubits.dart';
import 'goal_display.dart';
import 'goal_log_sheet.dart';
import 'goal_ring.dart';

/// Home card with a ring per daily goal and quick-add buttons.
class TodaysProgressCard extends StatefulWidget {
  const TodaysProgressCard({super.key});

  @override
  State<TodaysProgressCard> createState() => _TodaysProgressCardState();
}

class _TodaysProgressCardState extends State<TodaysProgressCard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: the step permission may have changed.
    _lifecycle = AppLifecycleListener(onResume: _refreshStepAccess);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshStepAccess() {
    final cubit = context.read<TodayGoalsCubit>();
    final state = cubit.state;
    if (state is ViewLoaded<TodayGoals> &&
        state.data.stepStatus != StepStatus.active) {
      cubit.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodayGoalsCubit, ViewState<TodayGoals>>(
      builder: (context, state) => switch (state) {
        ViewLoading<TodayGoals>() => const SizedBox.shrink(),
        ViewError<TodayGoals>(:final message) => AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('Today’s progress'),
              Text(message),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.read<TodayGoalsCubit>().start(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
        ViewLoaded<TodayGoals>(:final data) => _Goals(today: data),
      },
    );
  }
}

class _Goals extends StatelessWidget {
  const _Goals({required this.today});

  final TodayGoals today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'Today’s progress',
            trailing: SizedBox.square(
              dimension: 32,
              child: IconButton(
                tooltip: 'Edit daily goals',
                padding: EdgeInsets.zero,
                iconSize: 20,
                onPressed: () => context.push(RoutePaths.dailyGoals),
                icon: const Icon(Icons.tune),
              ),
            ),
          ),
          if (today.isEmpty)
            Text(
              'No daily goals yet. Add water, steps or your own.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Text(
              '${today.completedCount} of ${today.goals.length} goals reached',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final progress in today.goals)
              _GoalRow(progress: progress, stepStatus: today.stepStatus),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.progress, required this.stepStatus});

  final GoalProgress progress;
  final StepStatus stepStatus;

  DailyGoal get _goal => progress.goal;

  bool get _isSteps => _goal.type == DailyGoalType.steps;

  Future<void> _add(BuildContext context, double delta) async {
    final cubit = context.read<TodayGoalsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final units = context.units;
    final outcome = await cubit.addProgress(_goal.id, delta);
    switch (outcome) {
      case ActionDone(value: final applied):
        if (applied == 0) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              // Undo is a convenience, so the bar still times out.
              persist: false,
              content: Text(
                '${applied > 0 ? 'Added' : 'Took back'} '
                '${_goal.amountText(units, applied.abs())}',
              ),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => cubit.addProgress(_goal.id, -applied),
              ),
            ),
          );
      case ActionFailed(:final message):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _log(BuildContext context) async {
    final delta = await showGoalLogSheet(context, _goal);
    if (delta == null || !context.mounted) return;
    await _add(context, delta);
  }

  Future<void> _enableSteps(BuildContext context) async {
    final access = await context.read<TodayGoalsCubit>().enableStepCounting();
    if (!context.mounted) return;
    switch (access) {
      case StepAccess.granted:
        break;
      case StepAccess.denied || StepAccess.permanentlyDenied:
        showMessage(
          context,
          'Without step access, you can still add steps by hand.',
        );
      case StepAccess.unsupported:
        showMessage(context, 'This phone can’t count steps.');
    }
  }

  String? get _stepHint => !_isSteps
      ? null
      : switch (stepStatus) {
          StepStatus.active => null,
          StepStatus.needsPermission => 'Allow step counting to track steps',
          StepStatus.blocked => 'Step counting is off in system settings',
          StepStatus.unavailable => 'No step sensor; add steps by hand',
        };

  /// The theme's full-width buttons don't fit in a row.
  static final _quickAddStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  );

  Widget _action(BuildContext context) {
    final units = context.units;
    switch (_goal.type) {
      case DailyGoalType.water:
        final serving = units.waterServingsMl.first;
        return FilledButton.tonal(
          style: _quickAddStyle,
          onPressed: () => _add(context, serving),
          child: Text('+${units.water(serving)}'),
        );
      case DailyGoalType.custom:
        return FilledButton.tonal(
          style: _quickAddStyle,
          onPressed: () => _add(context, _goal.increment),
          child: Text('+${Formatters.weight(_goal.increment)}'),
        );
      case DailyGoalType.steps:
        return switch (stepStatus) {
          StepStatus.needsPermission => TextButton(
            onPressed: () => _enableSteps(context),
            child: const Text('Turn on'),
          ),
          StepStatus.blocked => TextButton(
            onPressed: () => context.read<TodayGoalsCubit>().openStepSettings(),
            child: const Text('Settings'),
          ),
          StepStatus.active || StepStatus.unavailable => IconButton(
            tooltip: 'Add steps',
            onPressed: () => _log(context),
            icon: const Icon(Icons.add),
          ),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = _stepHint;
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: () => _log(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            GoalRing(
              fraction: progress.fraction,
              icon: _goal.icon,
              complete: progress.isComplete,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _goal.displayName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _goal.progressText(context.units, progress.amount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progress.isComplete
                          ? context.semanticColors.success
                          : null,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.semanticColors.mutedText,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _action(context),
          ],
        ),
      ),
    );
  }
}
