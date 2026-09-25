import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/l10n/enum_labels.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/muscle_chips.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/exercise_filter.dart';
import '../cubits/exercise_cubits.dart';

/// All exercises, searchable by name and muscle. In [pickMode] tapping an
/// exercise (or creating one) returns its ID to the caller.
class ExerciseLibraryView extends StatefulWidget {
  const ExerciseLibraryView({
    super.key,
    this.pickMode = false,
    this.alreadyAdded = const {},
  });

  final bool pickMode;

  /// In pick mode: exercises already in the day, shown but not selectable.
  final Set<String> alreadyAdded;

  @override
  State<ExerciseLibraryView> createState() => _ExerciseLibraryViewState();
}

class _ExerciseLibraryViewState extends State<ExerciseLibraryView> {
  late final TextEditingController _search;
  ExerciseFilter _filter = const ExerciseFilter();

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Exercise exercise) {
    if (widget.pickMode) {
      context.pop(exercise.id);
    } else {
      context.push(RoutePaths.exercise(exercise.id));
    }
  }

  Future<void> _create() async {
    final id = await context.push<String>(RoutePaths.newExercise);
    if (id != null && widget.pickMode && mounted) context.pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (widget.pickMode ? 'library.addExercise' : 'library.title').tr(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text('exercise.newExercise'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              0,
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'library.search'.tr(),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (text) => setState(
                () => _filter = ExerciseFilter(
                  query: text,
                  muscle: _filter.muscle,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.sm,
              ),
              children: [
                for (final muscle in MuscleGroup.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    child: FilterChip(
                      label: Text(muscle.label),
                      selected: _filter.muscle == muscle,
                      onSelected: (on) => setState(
                        () => _filter = ExerciseFilter(
                          query: _filter.query,
                          muscle: on ? muscle : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ViewStateBuilder<ExerciseLibraryCubit, List<Exercise>>(
              onRetry: (cubit) => cubit.start(),
              builder: (context, all) {
                final exercises = _filter.apply(all, displayName: seedName);
                if (exercises.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'library.noResults'.tr(),
                    message: 'library.noResultsHint'.tr(),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    96,
                  ),
                  itemCount: exercises.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    final added =
                        widget.pickMode &&
                        widget.alreadyAdded.contains(exercise.id);
                    return _ExerciseRow(
                      exercise: exercise,
                      pickMode: widget.pickMode,
                      alreadyAdded: added,
                      onTap: added ? null : () => _open(exercise),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.pickMode,
    required this.onTap,
    this.alreadyAdded = false,
  });

  final Exercise exercise;
  final bool pickMode;
  final bool alreadyAdded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        seedName(exercise.name),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (exercise.isCustom) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.person_outline, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                MuscleChips(
                  primary: [exercise.primaryMuscle],
                  secondary: exercise.secondaryMuscles,
                  dense: true,
                ),
              ],
            ),
          ),
          if (alreadyAdded)
            Text('library.inThisWorkout'.tr(), style: theme.textTheme.bodySmall)
          else
            Icon(pickMode ? Icons.add_circle_outline : Icons.chevron_right),
        ],
      ),
    );
  }
}
