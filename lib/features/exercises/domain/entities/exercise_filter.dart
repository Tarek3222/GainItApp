import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';

/// Library search: name text and/or a muscle the exercise targets.
class ExerciseFilter extends Equatable {
  const ExerciseFilter({this.query = '', this.muscle});

  final String query;
  final MuscleGroup? muscle;

  bool get isEmpty => query.trim().isEmpty && muscle == null;

  /// [displayName] is the name as shown (e.g. translated); the search
  /// matches it as well as the stored name.
  bool matches(Exercise exercise, {String Function(String name)? displayName}) {
    final text = query.trim().toLowerCase();
    if (text.isNotEmpty &&
        !exercise.name.toLowerCase().contains(text) &&
        !(displayName?.call(exercise.name).toLowerCase().contains(text) ??
            false)) {
      return false;
    }
    final target = muscle;
    return target == null || exercise.targetMuscles.contains(target);
  }

  List<Exercise> apply(
    List<Exercise> exercises, {
    String Function(String name)? displayName,
  }) => isEmpty
      ? exercises
      : [
          for (final e in exercises)
            if (matches(e, displayName: displayName)) e,
        ];

  @override
  List<Object?> get props => [query, muscle];
}
