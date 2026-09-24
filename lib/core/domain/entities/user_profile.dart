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
    this.birthDate,
    this.photoPath,
  });

  final String id;
  final String name;
  final double heightCm;
  final TrainingGoal goal;
  final DateTime trainingStartDate;
  final UnitSystem unitSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Anchored on the day the user entered their age: someone who says "25"
  /// on 2026-03-01 is stored as born 2001-03-01, so the shown age only goes
  /// up a full year later. `null` for profiles created before age existed.
  final DateTime? birthDate;

  /// File name of the profile photo in the app's media folder (see
  /// `MediaStore`); never an absolute path, which changes on iOS updates.
  final String? photoPath;

  /// Whole years between [birthDate] and [today].
  int? ageOn(DateTime today) {
    final born = birthDate;
    if (born == null) return null;
    final hadAnniversary =
        today.month > born.month ||
        (today.month == born.month && today.day >= born.day);
    return today.year - born.year - (hadAnniversary ? 0 : 1);
  }

  /// The birth date for someone who is [age] on [today].
  static DateTime birthDateFor(int age, DateTime today) =>
      DateTime(today.year - age, today.month, today.day);

  UserProfile copyWith({
    String? name,
    double? heightCm,
    TrainingGoal? goal,
    DateTime? trainingStartDate,
    UnitSystem? unitSystem,
    DateTime? birthDate,
    String? photoPath,
    bool clearPhoto = false,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      heightCm: heightCm ?? this.heightCm,
      goal: goal ?? this.goal,
      trainingStartDate: trainingStartDate ?? this.trainingStartDate,
      unitSystem: unitSystem ?? this.unitSystem,
      birthDate: birthDate ?? this.birthDate,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
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
    birthDate,
    photoPath,
  ];
}
