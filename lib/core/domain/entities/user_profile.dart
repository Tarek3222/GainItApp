import 'package:equatable/equatable.dart';

import 'enums.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.heightCm,
    required this.goal,
    required this.trainingStartDate,
    required this.createdAt,
    required this.updatedAt,
    this.unitSystem = UnitSystem.metric,
  });

  final String id;
  final String name;
  final double heightCm;
  final TrainingGoal goal;
  final DateTime trainingStartDate;
  final UnitSystem unitSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? name,
    double? heightCm,
    TrainingGoal? goal,
    DateTime? trainingStartDate,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      heightCm: heightCm ?? this.heightCm,
      goal: goal ?? this.goal,
      trainingStartDate: trainingStartDate ?? this.trainingStartDate,
      unitSystem: unitSystem,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    heightCm,
    goal,
    trainingStartDate,
    unitSystem,
    createdAt,
    updatedAt,
  ];
}
