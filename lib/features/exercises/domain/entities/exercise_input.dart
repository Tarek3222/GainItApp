import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';

/// What the exercise editor submits, for a new or an existing exercise.
class ExerciseInput extends Equatable {
  const ExerciseInput({
    required this.name,
    required this.primaryMuscle,
    required this.category,
    this.secondaryMuscles = const [],
    this.instructions,
  });

  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final ExerciseCategory category;
  final String? instructions;

  @override
  List<Object?> get props => [
    name,
    primaryMuscle,
    secondaryMuscles,
    category,
    instructions,
  ];
}
