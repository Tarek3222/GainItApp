import 'package:easy_localization/easy_localization.dart';
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
      appBar: AppBar(title: Text('goals.title'.tr())),
      floatingActionButton: const _AddGoalButton(),
      body: ViewStateBuilder<DailyGoalsCubit, List<DailyGoal>>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, goals) => goals.isEmpty
            ? EmptyState(
                icon: Icons.flag_outlined,
                title: 'goals.empty'.tr(),
                message: 'goals.emptyHint'.tr(),
                action: FilledButton.icon(
                  onPressed: () => _addGoal(context, goals),
                  icon: const Icon(Icons.add),
                  label: Text('goals.addGoal'.tr()),
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
            label: Text('goals.addGoal'.tr()),
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
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (type, name, icon, description) in [
            (
              DailyGoalType.water,
              'goals.water'.tr(),
              Icons.water_drop_outlined,
              'goals.waterHint'.tr(),
            ),
            (
              DailyGoalType.steps,
              'goals.steps'.tr(),
              Icons.directions_walk,
              'goals.stepsHint'.tr(),
            ),
            (
              DailyGoalType.custom,
              'goals.custom'.tr(),
              Icons.flag_outlined,
              'goals.customHint'.tr(),
            ),
          ])
            ListTile(
              enabled: type == DailyGoalType.custom || !taken.contains(type),
              leading: Icon(icon),
              title: Text(name),
              subtitle: Text(
                type != DailyGoalType.custom && taken.contains(type)
                    ? 'goals.alreadyAdded'.tr()
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
    title: 'goals.newGoal'.tr(),
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
        title: Text(
          'goals.removeTitle'.tr(namedArgs: {'goal': goal.displayName}),
        ),
        content: Text('goals.removeMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('common.remove'.tr()),
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
                  'goals.perDay'.tr(
                    namedArgs: {
                      'amount': goal.amountText(context.units, goal.target),
                    },
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(goal.reminderSummary, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'goals.removeGoal'.tr(
              namedArgs: {'goal': goal.displayName},
            ),
            onPressed: () => _remove(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
