import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/workout_session.dart';

/// Raw startup data from storage.
class StartupData extends Equatable {
  const StartupData({
    required this.hasProfile,
    this.activeSession,
    this.activeExercises = const [],
    this.activeSets = const [],
  });

  final bool hasProfile;
  final WorkoutSession? activeSession;
  final List<SessionExercise> activeExercises;
  final List<SetLog> activeSets;

  @override
  List<Object?> get props => [
    hasProfile,
    activeSession,
    activeExercises,
    activeSets,
  ];
}

/// An interrupted workout the user can resume or discard (spec §20).
class InterruptedWorkout extends Equatable {
  const InterruptedWorkout({
    required this.sessionId,
    required this.workoutName,
    required this.completedSets,
    required this.totalSets,
  });

  final String sessionId;
  final String workoutName;
  final int completedSets;
  final int totalSets;

  @override
  List<Object?> get props => [sessionId, workoutName, completedSets, totalSets];
}

class StartupStatus extends Equatable {
  const StartupStatus({required this.hasProfile, this.interruptedWorkout});

  final bool hasProfile;
  final InterruptedWorkout? interruptedWorkout;

  @override
  List<Object?> get props => [hasProfile, interruptedWorkout];
}
