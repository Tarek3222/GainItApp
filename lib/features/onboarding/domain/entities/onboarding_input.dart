import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';

class OnboardingInput extends Equatable {
  const OnboardingInput({
    required this.name,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.goal,
    required this.trainingStartDate,
    this.unitSystem = UnitSystem.metric,
  });

  final String name;
  final double heightCm;
  final double weightKg;
  final int age;
  final TrainingGoal goal;
  final DateTime trainingStartDate;
  final UnitSystem unitSystem;

  @override
  List<Object?> get props => [
    name,
    heightCm,
    weightKg,
    age,
    goal,
    trainingStartDate,
    unitSystem,
  ];
}
