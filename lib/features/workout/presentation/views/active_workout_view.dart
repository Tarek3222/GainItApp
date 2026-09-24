import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/active_workout.dart';
import '../cubits/active_workout_cubit.dart';
import '../cubits/rest_timer_cubit.dart';
import '../widgets/exercise_panel.dart';
import '../widgets/rest_timer_panel.dart';

class ActiveWorkoutView extends StatelessWidget {
  const ActiveWorkoutView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActiveWorkoutCubit, ActiveWorkoutState>(
      listenWhen: (prev, curr) =>
          curr is ActiveWorkoutClosed ||
          (curr is ActiveWorkoutLoaded &&
              curr.message != null &&
              (prev is! ActiveWorkoutLoaded ||
                  prev.messageId != curr.messageId)),
      listener: (context, state) {
        switch (state) {
          case ActiveWorkoutClosed(:final sessionId, :final completed):
            context.read<RestTimerCubit>().stop();
            if (completed) {
              context.go(RoutePaths.workoutSummary(sessionId));
            } else {
              context.go(RoutePaths.home);
            }
          case ActiveWorkoutLoaded(:final message?):
            showMessage(context, message);
          default:
            break;
        }
      },
      buildWhen: (prev, curr) =>
          prev.runtimeType != curr.runtimeType ||
          (curr is ActiveWorkoutLoaded &&
              prev is ActiveWorkoutLoaded &&
              prev.workout != curr.workout),
      builder: (context, state) {
        return switch (state) {
          ActiveWorkoutLoaded(:final workout) => _WorkoutScaffold(
            workout: workout,
          ),
          ActiveWorkoutError(:final message) => Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              message: message,
              onRetry: context.read<ActiveWorkoutCubit>().start,
            ),
          ),
          ActiveWorkoutLoading() ||
          ActiveWorkoutClosed() => const Scaffold(body: LoadingView()),
        };
      },
    );
  }
}

class _WorkoutScaffold extends StatefulWidget {
  const _WorkoutScaffold({required this.workout});

  final ActiveWorkout workout;

  @override
  State<_WorkoutScaffold> createState() => _WorkoutScaffoldState();
}

class _WorkoutScaffoldState extends State<_WorkoutScaffold> {
  late final PageController _pages;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.workout.currentIndex ?? 0;
    _pages = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(covariant _WorkoutScaffold old) {
    super.didUpdateWidget(old);
    // Auto-advance when the exercise being viewed was just finished.
    final previous = old.workout.currentIndex;
    final next = widget.workout.currentIndex;
    if (next != null && previous != next && _page == previous) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) {
          _pages.animateToPage(
            next,
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ActiveExercise get _viewed => widget.workout.exercises[_page];

  Future<void> _logSet(
    ActiveExercise exercise,
    double weight,
    int reps,
    int? rir,
  ) async {
    final saved = await context.read<ActiveWorkoutCubit>().logSet(
      exercise: exercise,
      weight: weight,
      reps: reps,
      rir: rir,
    );
    if (!saved || !mounted) return;
    final timer = context.read<RestTimerCubit>();
    if (timer.state.settings.autoStartRestTimer) _startRest(exercise);
  }

  void _startRest(ActiveExercise exercise) {
    context.read<RestTimerCubit>().start(
      seconds: exercise.snapshot.restSeconds,
      exerciseName: exercise.snapshot.exerciseName,
    );
  }

  Future<void> _confirmFinish() async {
    final progress = widget.workout.progress;
    final remaining = progress.totalSets - progress.completedSets;
    final ok = await _confirm(
      title: 'Finish workout?',
      message: remaining > 0
          ? '$remaining planned sets are not logged yet. They will not count.'
          : 'Great work. Save this workout to your history.',
      confirm: 'Finish',
    );
    if (ok && mounted) await context.read<ActiveWorkoutCubit>().finish();
  }

  Future<void> _confirmDiscard() async {
    final ok = await _confirm(
      title: 'Discard workout?',
      message:
          'This workout will not count toward history or progression. '
          'This cannot be undone.',
      confirm: 'Discard',
      destructive: true,
    );
    if (ok && mounted) await context.read<ActiveWorkoutCubit>().abandon();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirm,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: destructive
                ? TextButton.styleFrom(
                    foregroundColor: context.semanticColors.danger,
                  )
                : null,
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.session.workoutName, overflow: TextOverflow.ellipsis),
            Text(
              '${workout.progress.completedSets} of '
              '${workout.progress.totalSets} sets',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Start rest timer',
            onPressed: () => _startRest(_viewed),
            icon: const Icon(Icons.timer_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'finish' ? _confirmFinish() : _confirmDiscard(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'finish', child: Text('Finish workout')),
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: workout.progress.fraction,
            minHeight: 4,
          ),
        ),
      ),
      body: Column(
        children: [
          _ExerciseStrip(
            exercises: workout.exercises,
            selected: _page,
            onSelected: (index) => _pages.animateToPage(
              index,
              duration: AppDurations.medium,
              curve: Curves.easeOut,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: workout.exercises.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final exercise = workout.exercises[index];
                final cubit = context.read<ActiveWorkoutCubit>();
                return BlocSelector<RestTimerCubit, RestTimerState, bool>(
                  selector: (state) => state.isResting,
                  builder: (context, isResting) => ExercisePanel(
                    exercise: exercise,
                    isResting: isResting,
                    onLogSet: (weight, reps, rir) =>
                        _logSet(exercise, weight, reps, rir),
                    onUndoSet: (set) => cubit.undoSet(set.id),
                    onToggleSkip: () =>
                        cubit.setSkipped(exercise, skip: !exercise.isSkipped),
                  ),
                );
              },
            ),
          ),
          if (workout.allDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: FilledButton.icon(
                onPressed: context.read<ActiveWorkoutCubit>().finish,
                icon: const Icon(Icons.flag),
                label: const Text('Finish workout'),
              ),
            ),
          const RestTimerPanel(),
        ],
      ),
    );
  }
}

/// Horizontal list of exercises with completion markers for quick jumping.
class _ExerciseStrip extends StatelessWidget {
  const _ExerciseStrip({
    required this.exercises,
    required this.selected,
    required this.onSelected,
  });

  final List<ActiveExercise> exercises;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return SizedBox(
      height: AppSpacing.minTouchTarget + AppSpacing.sm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xs,
        ),
        itemCount: exercises.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final e = exercises[index];
          final icon = e.isSkipped
              ? Icon(Icons.skip_next, size: 16, color: semantic.mutedText)
              : e.isComplete
              ? Icon(Icons.check_circle, size: 16, color: semantic.success)
              : null;
          return ChoiceChip(
            avatar: icon,
            label: Text(
              '${index + 1}. ${e.snapshot.exerciseName}',
              overflow: TextOverflow.ellipsis,
            ),
            selected: index == selected,
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}
