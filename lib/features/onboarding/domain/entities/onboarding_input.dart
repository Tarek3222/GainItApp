import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';

class OnboardingInput extends Equatable {
  const OnboardingInput({
    required this.name,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.trainingStartDate,
  });

  final String name;
  final double heightCm;
  final double weightKg;
  final TrainingGoal goal;
  final DateTime trainingStartDate;

  @override
  List<Object?> get props => [
    name,
    heightCm,
    weightKg,
    goal,
    trainingStartDate,
  ];
}
