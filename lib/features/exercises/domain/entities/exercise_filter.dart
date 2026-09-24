import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';

/// Library search: name text and/or a muscle the exercise targets.
class ExerciseFilter extends Equatable {
  const ExerciseFilter({this.query = '', this.muscle});

  final String query;
  final MuscleGroup? muscle;

  bool get isEmpty => query.trim().isEmpty && muscle == null;

  bool matches(Exercise exercise) {
    final text = query.trim().toLowerCase();
    if (text.isNotEmpty && !exercise.name.toLowerCase().contains(text)) {
      return false;
    }
    final target = muscle;
    return target == null || exercise.targetMuscles.contains(target);
  }

  List<Exercise> apply(List<Exercise> exercises) =>
      isEmpty ? exercises : exercises.where(matches).toList();

  @override
  List<Object?> get props => [query, muscle];
}
