import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/domain/training/progression_engine.dart';
import '../../../../core/domain/training/workout_session_rules.dart';

/// Raw session data loaded by the repository.
class ActiveSessionData extends Equatable {
  const ActiveSessionData({
    required this.session,
    required this.exercises,
    required this.sets,
    required this.history,
  });

  final WorkoutSession session;
  final List<SessionExercise> exercises;
  final List<SetLog> sets;

  /// Previous completed performances per exerciseId, most recent first.
  final Map<String, List<ExerciseSessionPerformance>> history;

  @override
  List<Object?> get props => [session, exercises, sets, history];
}

/// UI-ready state of one exercise during a workout.
class ActiveExercise extends Equatable {
  const ActiveExercise({
    required this.snapshot,
    required this.sets,
    required this.recommendation,
    this.lastPerformance,
  });

  final SessionExercise snapshot;

  /// Working sets logged in this session, by set number.
  final List<SetLog> sets;
  final ExerciseSessionPerformance? lastPerformance;
  final Recommendation recommendation;

  int get completedSets => sets.length;
  bool get isSkipped => snapshot.isSkipped;
  bool get isComplete => isSkipped || completedSets >= snapshot.targetSets;

  int get nextSetNumber => WorkoutSessionRules.nextSetNumber(snapshot.id, sets);

  /// Starting values for the next set: repeat this session's last set,
  /// otherwise follow the recommendation.
  double? get suggestedWeight =>
      sets.isNotEmpty ? sets.last.actualWeight : recommendation.suggestedWeight;

  int get suggestedReps => sets.isNotEmpty
      ? sets.last.actualReps
      : recommendation.targetReps ?? snapshot.repMin;

  @override
  List<Object?> get props => [snapshot, sets, lastPerformance, recommendation];
}

class ActiveWorkout extends Equatable {
  const ActiveWorkout({
    required this.session,
    required this.exercises,
    required this.progress,
    this.currentIndex,
  });

  final WorkoutSession session;
  final List<ActiveExercise> exercises;
  final WorkoutProgress progress;

  /// First exercise with sets remaining; `null` when everything is done.
  final int? currentIndex;

  bool get allDone => currentIndex == null;

  @override
  List<Object?> get props => [session, exercises, progress, currentIndex];
}

/// Everything the user entered for one set.
class LogSetInput extends Equatable {
  const LogSetInput({
    required this.sessionExerciseId,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.plannedRepsMin,
    required this.plannedRepsMax,
    this.rir,
    this.plannedWeight,
  });

  final String sessionExerciseId;
  final int setNumber;
  final double weight;
  final int reps;
  final int? rir;
  final int plannedRepsMin;
  final int plannedRepsMax;
  final double? plannedWeight;

  @override
  List<Object?> get props => [
    sessionExerciseId,
    setNumber,
    weight,
    reps,
    rir,
    plannedRepsMin,
    plannedRepsMax,
    plannedWeight,
  ];
}
