import 'package:equatable/equatable.dart';

/// One research finding behind a coaching cue.
class GuideEvidence extends Equatable {
  const GuideEvidence({required this.finding, required this.citation});

  /// What the study found, in plain words.
  final String finding;

  /// Authors, year, title and journal of the study.
  final String citation;

  @override
  List<Object?> get props => [finding, citation];
}

/// How to perform an exercise for the best results, based on research.
class ExerciseGuide extends Equatable {
  const ExerciseGuide({
    required this.exerciseName,
    required this.setup,
    required this.execution,
    required this.tips,
    required this.mistakes,
    required this.evidence,
  });

  /// Name of the exercise the guide was written for. If the user renames a
  /// built-in exercise, the screen notes that the guide is for the original.
  final String exerciseName;
  final List<String> setup;
  final List<String> execution;

  /// Tempo, range of motion and effort advice.
  final List<String> tips;
  final List<String> mistakes;
  final List<GuideEvidence> evidence;

  @override
  List<Object?> get props => [
    exerciseName,
    setup,
    execution,
    tips,
    mistakes,
    evidence,
  ];
}
