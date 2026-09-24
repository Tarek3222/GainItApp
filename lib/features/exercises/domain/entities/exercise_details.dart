import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/program.dart';
import 'exercise_guide.dart';

/// Everything the exercise screen shows besides progress.
class ExerciseDetails extends Equatable {
  const ExerciseDetails({
    required this.exercise,
    required this.usedInDays,
    this.imageFile,
    this.videoFile,
    this.guide,
    this.guideUnavailable = false,
  });

  final Exercise exercise;

  /// Resolved absolute paths of the attached media, if present.
  final String? imageFile;
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
        imageFile: imageFile,
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
    imageFile,
    videoFile,
    guide,
    guideUnavailable,
    usedInDays,
  ];
}
