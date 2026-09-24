import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/program.dart';
import 'exercise_guide.dart';

/// A stored photo: its file name (to remove it) and resolved path (to show
/// it).
class ExerciseImage extends Equatable {
  const ExerciseImage({required this.fileName, required this.path});

  final String fileName;
  final String path;

  @override
  List<Object?> get props => [fileName, path];
}

/// Everything the exercise screen shows besides progress.
class ExerciseDetails extends Equatable {
  const ExerciseDetails({
    required this.exercise,
    required this.usedInDays,
    this.images = const [],
    this.videoFile,
    this.guide,
    this.guideUnavailable = false,
  });

  final Exercise exercise;

  /// Photos whose files still exist, in order.
  final List<ExerciseImage> images;

  /// Resolved absolute path of the video, if present.
  final String? videoFile;

  /// Research-based guide for built-in exercises; `null` for custom ones.
  final ExerciseGuide? guide;

  /// The guide exists but could not be loaded (the screen offers a retry).
  final bool guideUnavailable;

  /// Plan days that include the exercise.
  final List<WorkoutDay> usedInDays;

  ExerciseDetails withGuide(ExerciseGuide? guide, {bool unavailable = false}) =>
      ExerciseDetails(
        exercise: exercise,
        usedInDays: usedInDays,
        images: images,
        videoFile: videoFile,
        guide: guide,
        guideUnavailable: unavailable,
      );

  /// The user changed a built-in exercise's name, so the bundled guide may
  /// describe a different movement.
  bool get guideIsForOriginal {
    final g = guide;
    return g != null &&
        g.exerciseName.isNotEmpty &&
        g.exerciseName != exercise.name;
  }

  @override
  List<Object?> get props => [
    exercise,
    images,
    videoFile,
    guide,
    guideUnavailable,
    usedInDays,
  ];
}
