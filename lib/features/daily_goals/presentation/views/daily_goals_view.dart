import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/daily_goal_entities.dart';
import '../cubits/daily_goal_cubits.dart';
import '../widgets/goal_display.dart';
import '../widgets/goal_editor_sheet.dart';

/// Add, edit and remove daily goals and their reminders.
class DailyGoalsView extends StatelessWidget {
  const DailyGoalsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily goals')),
      floatingActionButton: const _AddGoalButton(),
      body: ViewStateBuilder<DailyGoalsCubit, List<DailyGoal>>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, goals) => goals.isEmpty
            ? EmptyState(
                icon: Icons.flag_outlined,
                title: 'No daily goals',
                message:
                    'Track water, steps or anything you want to do every day.',
                action: FilledButton.icon(
                  onPressed: () => _addGoal(context, goals),
                  icon: const Icon(Icons.add),
                  label: const Text('Add goal'),
                ),
              )
            : PageBody(
                children: [
                  for (final goal in goals) ...[
                    _GoalTile(goal: goal),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Room for the floating button.
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
      ),
    );
  }
}

class _AddGoalButton extends StatelessWidget {
  const _AddGoalButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyGoalsCubit, ViewState<List<DailyGoal>>>(
      builder: (context, state) => switch (state) {
        ViewLoaded(:final data)
            when data.isNotEmpty && data.length < Validators.maxDailyGoals =>
          FloatingActionButton.extended(
            onPressed: () => _addGoal(context, data),
            icon: const Icon(Icons.add),
            label: const Text('Add goal'),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

Future<void> _addGoal(BuildContext context, List<DailyGoal> goals) async {
  final cubit = context.read<DailyGoalsCubit>();
  final taken = {for (final g in goals) g.type};
  final type = await showModalBottomSheet<DailyGoalType>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (type, name, icon, description) in const [
            (
              DailyGoalType.water,
              'Water',
              Icons.water_drop_outlined,
              'Quick-add glasses through the day',
            ),
            (
              DailyGoalType.steps,
              'Steps',
              Icons.directions_walk,
              'Counted by your phone',
            ),
            (
              DailyGoalType.custom,
              'Your own goal',
              Icons.flag_outlined,
              'Anything with a daily target',
            ),
          ])
            ListTile(
              enabled: type == DailyGoalType.custom || !taken.contains(type),
              leading: Icon(icon),
              title: Text(name),
              subtitle: Text(
                type != DailyGoalType.custom && taken.contains(type)
                    ? 'Already added'
                    : description,
              ),
              onTap: () => Navigator.of(sheetContext).pop(type),
            ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return;
  await showGoalEditorSheet(
    context,
    initial: GoalInput.defaultsFor(type),
    title: 'New goal',
    onSave: cubit.save,
  );
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final DailyGoal goal;

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<DailyGoalsCubit>();
    await showGoalEditorSheet(
      context,
      initial: GoalInput.fromGoal(goal),
      title: goal.displayName,
      onSave: (input) => cubit.save(input, existing: goal),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final cubit = context.read<DailyGoalsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${goal.displayName}?'),
        content: const Text('Its progress history is removed too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final outcome = await cubit.remove(goal);
    if (outcome case ActionFailed(:final message) when context.mounted) {
      showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => _edit(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.semanticColors.elevated,
            foregroundColor: theme.colorScheme.primary,
            child: Icon(goal.icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.displayName, style: theme.textTheme.titleMedium),
                Text(
                  '${goal.amountText(context.units, goal.target)} a day',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(goal.reminderSummary, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${goal.displayName}',
            onPressed: () => _remove(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
