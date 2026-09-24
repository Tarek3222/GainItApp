import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/muscle_chips.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../../progress/presentation/views/exercise_progress_view.dart';
import '../../domain/entities/exercise_details.dart';
import '../../domain/entities/exercise_guide.dart';
import '../../domain/usecases/exercise_use_cases.dart';
import '../cubits/exercise_cubits.dart';
import '../widgets/exercise_video_player.dart';

/// One exercise: how to do it (muscles, media, research guide) and progress.
class ExerciseDetailView extends StatelessWidget {
  const ExerciseDetailView({super.key});

  Future<void> _archive(BuildContext context, String name) async {
    final cubit = context.read<ExerciseDetailsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
          'It will be removed from the library and from every plan day. '
          'Your past workouts and progress stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.semanticColors.danger,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final outcome = await cubit.archive();
    if (!context.mounted) return;
    switch (outcome) {
      case ActionDone():
        context.pop();
      case ActionFailed(:final message):
        showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title:
              BlocSelector<
                ExerciseDetailsCubit,
                ViewState<ExerciseDetails>,
                String
              >(
                selector: (state) => switch (state) {
                  ViewLoaded(:final data) => data.exercise.name,
                  _ => '',
                },
                builder: (_, name) => Text(name),
              ),
          actions: [
            BlocSelector<
              ExerciseDetailsCubit,
              ViewState<ExerciseDetails>,
              ({String id, String name, bool archived})?
            >(
              selector: (state) => switch (state) {
                ViewLoaded(:final data) => (
                  id: data.exercise.id,
                  name: data.exercise.name,
                  archived: data.exercise.isArchived,
                ),
                _ => null,
              },
              builder: (context, exercise) =>
                  exercise == null || exercise.archived
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit exercise',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => context.push(
                            RoutePaths.editExercise(exercise.id),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (_) => _archive(context, exercise.name),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Remove from library'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Guide'),
              Tab(text: 'Progress'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ViewStateBuilder<ExerciseDetailsCubit, ExerciseDetails>(
              onRetry: (cubit) => cubit.start(),
              builder: (context, details) => _GuideTab(details: details),
            ),
            const ExerciseProgressTab(),
          ],
        ),
      ),
    );
  }
}

class _GuideTab extends StatelessWidget {
  const _GuideTab({required this.details});

  final ExerciseDetails details;

  Future<void> _restore(BuildContext context) async {
    final outcome = await context.read<ExerciseDetailsCubit>().restore();
    if (!context.mounted) return;
    showMessage(context, switch (outcome) {
      ActionDone() => 'Back in your library.',
      ActionFailed(:final message) => message,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = details.exercise;
    final guide = details.guide;
    final notes = exercise.instructions;
    // Eager: the video player must not be torn down when scrolled away.
    return PageBody(
      eager: true,
      children: [
        const SectionLabel('Target muscles'),
        MuscleChips(
          primary: [exercise.primaryMuscle],
          secondary: exercise.secondaryMuscles,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            if (exercise.category == ExerciseCategory.compound)
              'Compound (several joints)'
            else
              'Isolation (one joint)',
            if (details.usedInDays.isNotEmpty)
              'In your plan: '
                  '${details.usedInDays.map((d) => Formatters.weekday(d.weekday)).join(', ')}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (exercise.isArchived) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Removed from your library. Past workouts still show it.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.semanticColors.warning,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _restore(context),
                  child: const Text('Restore'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _MediaSection(details: details),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('Your notes'),
          AppCard(child: Text(notes)),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (details.guideIsForOriginal && guide != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'This guide was written for "${guide.exerciseName}". '
              'You renamed the exercise, so check it still applies.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.semanticColors.warning,
              ),
            ),
          ),
        if (guide != null)
          _GuideContent(guide: guide)
        else if (details.guideUnavailable)
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "The guide couldn't be loaded",
            action: OutlinedButton(
              onPressed: () => context.read<ExerciseDetailsCubit>().start(),
              child: const Text('Try again'),
            ),
          )
        else if (notes == null || notes.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No guide yet',
            message: 'Add your own cues with Edit, or attach a video.',
          ),
      ],
    );
  }
}

class _GuideContent extends StatelessWidget {
  const _GuideContent({required this.guide});

  final ExerciseGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bullets(title: 'Setup', lines: guide.setup),
        _Bullets(title: 'How to do it', lines: guide.execution),
        _Bullets(title: 'Get the most from it', lines: guide.tips),
        _Bullets(title: 'Common mistakes', lines: guide.mistakes),
        if (guide.evidence.isNotEmpty) ...[
          const SectionLabel('What research says'),
          for (final e in guide.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.finding, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.citation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: context.semanticColors.mutedText,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy citation',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: e.citation),
                            );
                            if (context.mounted) {
                              showMessage(
                                context,
                                'Citation copied. Paste it into a search to '
                                'find the study.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Photo and video of the exercise, with add / replace / remove actions.
class _MediaSection extends StatelessWidget {
  const _MediaSection({required this.details});

  final ExerciseDetails details;

  Future<void> _add(BuildContext context, ExerciseMediaKind kind) async {
    final cubit = context.read<ExerciseDetailsCubit>();
    final isVideo = kind == ExerciseMediaKind.video;
    final source = await showModalBottomSheet<MediaSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isVideo ? Icons.videocam_outlined : Icons.photo_camera_outlined,
              ),
              title: Text(isVideo ? 'Record video' : 'Take photo'),
              onTap: () => Navigator.pop(context, MediaSource.camera),
            ),
            ListTile(
              leading: Icon(
                isVideo
                    ? Icons.video_library_outlined
                    : Icons.photo_library_outlined,
              ),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, MediaSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final outcome = await cubit.attachMedia(kind, source);
    if (outcome case ActionFailed(:final message) when context.mounted) {
      showMessage(context, message);
    }
  }

  Future<void> _remove(BuildContext context, ExerciseMediaKind kind) async {
    final outcome = await context.read<ExerciseDetailsCubit>().removeMedia(
      kind,
    );
    if (outcome case ActionFailed(:final message) when context.mounted) {
      showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = details.imageFile;
    final video = details.videoFile;
    final editable = !details.exercise.isArchived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Photo & video'),
        if (image != null) ...[
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: Image.file(
              File(image),
              fit: BoxFit.cover,
              cacheWidth: 1080,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          if (editable)
            _MediaActions(
              onReplace: () => _add(context, ExerciseMediaKind.image),
              onRemove: () => _remove(context, ExerciseMediaKind.image),
              label: 'photo',
            ),
        ],
        if (video != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ExerciseVideoPlayer(path: video),
          if (editable)
            _MediaActions(
              onReplace: () => _add(context, ExerciseMediaKind.video),
              onRemove: () => _remove(context, ExerciseMediaKind.video),
              label: 'video',
            ),
        ],
        if (editable && (image == null || video == null))
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (image == null)
                OutlinedButton.icon(
                  onPressed: () => _add(context, ExerciseMediaKind.image),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add photo'),
                ),
              if (video == null)
                OutlinedButton.icon(
                  onPressed: () => _add(context, ExerciseMediaKind.video),
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Add video'),
                ),
            ],
          ),
      ],
    );
  }
}

class _MediaActions extends StatelessWidget {
  const _MediaActions({
    required this.onReplace,
    required this.onRemove,
    required this.label,
  });

  final VoidCallback onReplace;
  final VoidCallback onRemove;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(onPressed: onReplace, child: Text('Replace $label')),
      TextButton(
        onPressed: onRemove,
        style: TextButton.styleFrom(
          foregroundColor: context.semanticColors.danger,
        ),
        child: Text('Remove $label'),
      ),
    ],
  );
}
