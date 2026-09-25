import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/l10n/seed_names.dart';
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
import '../widgets/exercise_media_gallery.dart';

/// One exercise: how to do it (muscles, media, research guide) and progress.
class ExerciseDetailView extends StatelessWidget {
  const ExerciseDetailView({super.key});

  Future<void> _archive(BuildContext context, String name) async {
    final cubit = context.read<ExerciseDetailsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('exercise.removeTitle'.tr(namedArgs: {'name': name})),
        content: Text('exercise.removeMessage'.tr()),
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
                  ViewLoaded(:final data) => seedName(data.exercise.name),
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
                  name: seedName(data.exercise.name),
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
                          tooltip: 'exercise.edit'.tr(),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => context.push(
                            RoutePaths.editExercise(exercise.id),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (_) => _archive(context, exercise.name),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('exercise.removeFromLibrary'.tr()),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'exercise.guideTab'.tr()),
              Tab(text: 'exercise.progressTab'.tr()),
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
      ActionDone() => 'exercise.restored'.tr(),
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
        SectionLabel('common.targetMuscles'.tr()),
        MuscleChips(
          primary: [exercise.primaryMuscle],
          secondary: exercise.secondaryMuscles,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            if (exercise.category == ExerciseCategory.compound)
              'exercise.compound'.tr()
            else
              'exercise.isolation'.tr(),
            if (details.usedInDays.isNotEmpty)
              'exercise.inYourPlan'.tr(
                namedArgs: {
                  'days': details.usedInDays
                      .map((d) => Formatters.weekday(d.weekday))
                      .join('common.listSeparator'.tr()),
                },
              ),
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
                    'exercise.archivedNote'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.semanticColors.warning,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _restore(context),
                  child: Text('exercise.restore'.tr()),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _MediaSection(details: details),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel('exercise.yourNotes'.tr()),
          AppCard(child: Text(notes)),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (details.guideIsForOriginal && guide != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'exercise.guideRenamed'.tr(
                namedArgs: {'name': seedName(guide.exerciseName)},
              ),
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
            title: 'exercise.guideFailed'.tr(),
            action: OutlinedButton(
              onPressed: () => context.read<ExerciseDetailsCubit>().start(),
              child: Text('exercise.tryAgain'.tr()),
            ),
          )
        else if (notes == null || notes.isEmpty)
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'exercise.noGuide'.tr(),
            message: 'exercise.noGuideHint'.tr(),
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
        _Bullets(title: 'exercise.guide.setup'.tr(), lines: guide.setup),
        _Bullets(
          title: 'exercise.guide.execution'.tr(),
          lines: guide.execution,
        ),
        _Bullets(title: 'exercise.guide.tips'.tr(), lines: guide.tips),
        _Bullets(title: 'exercise.guide.mistakes'.tr(), lines: guide.mistakes),
        if (guide.evidence.isNotEmpty) ...[
          SectionLabel('exercise.guide.research'.tr()),
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
                          tooltip: 'exercise.copyCitation'.tr(),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: e.citation),
                            );
                            if (context.mounted) {
                              showMessage(
                                context,
                                'exercise.citationCopied'.tr(),
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

/// Photos and video of the exercise in a slider, with add / remove actions.
class _MediaSection extends StatelessWidget {
  const _MediaSection({required this.details});

  final ExerciseDetails details;

  Future<void> _add(BuildContext context, ExerciseMediaKind kind) async {
    final cubit = context.read<ExerciseDetailsCubit>();
    final isVideo = kind == ExerciseMediaKind.video;
    final source = await showModalBottomSheet<MediaSource>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isVideo ? Icons.videocam_outlined : Icons.photo_camera_outlined,
              ),
              title: Text(
                (isVideo ? 'exercise.recordVideo' : 'exercise.takePhoto').tr(),
              ),
              onTap: () => Navigator.pop(context, MediaSource.camera),
            ),
            ListTile(
              leading: Icon(
                isVideo
                    ? Icons.video_library_outlined
                    : Icons.photo_library_outlined,
              ),
              title: Text('exercise.chooseFromGallery'.tr()),
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

  void _report(BuildContext context, ActionOutcome<void> outcome) {
    if (outcome case ActionFailed(:final message)) {
      showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExerciseDetailsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('exercise.media'.tr()),
        ExerciseMediaGallery(
          details: details,
          editable: !details.exercise.isArchived,
          onAddImage: () => _add(context, ExerciseMediaKind.image),
          onAddVideo: () => _add(context, ExerciseMediaKind.video),
          onRemoveImage: (name) async {
            final outcome = await cubit.removeImage(name);
            if (context.mounted) _report(context, outcome);
          },
          onRemoveVideo: () async {
            final outcome = await cubit.removeVideo();
            if (context.mounted) _report(context, outcome);
          },
        ),
      ],
    );
  }
}
