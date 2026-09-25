import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/muscle_chips.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/plan_entities.dart';
import '../cubits/plan_cubits.dart';
import '../widgets/exercise_config_sheet.dart';

/// Customise one plan day: name, workout or rest, and its exercises
/// (add, remove, reorder, and sets / reps / rest per exercise).
class WorkoutDayEditorView extends StatelessWidget {
  const WorkoutDayEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('dayEditor.title'.tr())),
      body: ViewStateBuilder<WorkoutDayEditorCubit, WorkoutOverview>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, overview) => _EditorBody(overview: overview),
      ),
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody({required this.overview});

  final WorkoutOverview overview;

  void _report(BuildContext context, ActionOutcome<void> outcome) {
    if (outcome case ActionFailed(:final message) when context.mounted) {
      showMessage(context, message);
    }
  }

  Future<void> _rename(BuildContext context) async {
    final cubit = context.read<WorkoutDayEditorCubit>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: seedName(overview.day.name)),
    );
    if (name == null ||
        name.trim() == overview.day.name ||
        name.trim() == seedName(overview.day.name)) {
      return;
    }
    final outcome = await cubit.rename(name);
    if (context.mounted) _report(context, outcome);
  }

  Future<void> _setWorkout(BuildContext context, bool isWorkout) async {
    final outcome = await context.read<WorkoutDayEditorCubit>().setType(
      isWorkout ? DayType.workout : DayType.rest,
    );
    if (context.mounted) _report(context, outcome);
  }

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<WorkoutDayEditorCubit>();
    final exerciseId = await context.push<String>(
      RoutePaths.exercisePicker(
        exclude: [for (final e in overview.exercises) e.exerciseId],
      ),
    );
    if (exerciseId == null) return;
    final outcome = await cubit.addExercise(exerciseId);
    if (context.mounted) _report(context, outcome);
  }

  Future<void> _configure(BuildContext context, OverviewExercise e) async {
    final cubit = context.read<WorkoutDayEditorCubit>();
    final updated = await showExerciseConfigSheet(
      context,
      entry: e.config,
      exerciseName: seedName(e.name),
    );
    if (updated == null || updated == e.config) return;
    final outcome = await cubit.updateConfig(updated);
    if (context.mounted) _report(context, outcome);
  }

  Future<void> _remove(BuildContext context, OverviewExercise e) async {
    final cubit = context.read<WorkoutDayEditorCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'dayEditor.removeTitle'.tr(namedArgs: {'exercise': seedName(e.name)}),
        ),
        content: Text('dayEditor.removeMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.semanticColors.danger,
            ),
            child: Text('common.remove'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final outcome = await cubit.removeExercise(e.config.id);
    if (context.mounted) _report(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = overview.day;
    final exercises = overview.exercises;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          onTap: () => _rename(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.weekday(day.weekday),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(seedName(day.name), style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('dayEditor.workoutDay'.tr()),
          subtitle: Text(
            (day.isWorkout
                    ? 'dayEditor.trainOnDay'
                    : 'dayEditor.restAndRecover')
                .tr(),
          ),
          value: day.isWorkout,
          onChanged: (v) => _setWorkout(context, v),
        ),
        if (day.isWorkout && overview.targetMuscles.isNotEmpty) ...[
          SectionLabel('common.targetMuscles'.tr()),
          MuscleChips(
            primary: overview.targetMuscles,
            secondary: overview.assistingMuscles,
            dense: true,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (day.isWorkout)
          SectionLabel(
            'dayEditor.exercises'.tr(),
            trailing: exercises.length > 1
                ? Text(
                    'dayEditor.dragToReorder'.tr(),
                    style: theme.textTheme.bodySmall,
                  )
                : null,
          ),
      ],
    );

    if (!day.isWorkout) {
      return PageBody(
        children: [
          header,
          const SizedBox(height: AppSpacing.md),
          if (exercises.isNotEmpty)
            Text(
              'dayEditor.keepsExercises'.plural(exercises.length),
              style: theme.textTheme.bodySmall,
            ),
        ],
      );
    }

    return ReorderableListView.builder(
      // Leaves room for the navigation bar the list scrolls under.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      header: header,
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: OutlinedButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: Text('dayEditor.addExercise'.tr()),
        ),
      ),
      buildDefaultDragHandles: false,
      itemCount: exercises.length,
      // newIndex is already adjusted for the removed item.
      onReorderItem: (oldIndex, newIndex) async {
        final outcome = await context.read<WorkoutDayEditorCubit>().move(
          oldIndex,
          newIndex,
        );
        if (context.mounted) _report(context, outcome);
      },
      itemBuilder: (context, index) {
        final e = exercises[index];
        final c = e.config;
        return Padding(
          key: ValueKey(c.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () => _configure(context, e),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.drag_indicator),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(seedName(e.name), style: theme.textTheme.titleSmall),
                      Text(
                        [
                          'dayEditor.configLine'.tr(
                            namedArgs: {
                              'sets': '${c.workingSets}',
                              'reps': Formatters.repRange(c.repMin, c.repMax),
                              'rest': Formatters.rest(
                                c.restMinSeconds,
                                c.restMaxSeconds,
                              ),
                            },
                          ),
                          if (c.supersetGroup case final group?)
                            'workout.superset'.tr(namedArgs: {'n': '$group'}),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'dayEditor.removeExercise'.tr(
                    namedArgs: {'exercise': seedName(e.name)},
                  ),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(context, e),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('dayEditor.dayName'.tr()),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: Validators.maxDayName,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}
