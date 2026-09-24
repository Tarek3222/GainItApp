import 'package:equatable/equatable.dart';

import 'enums.dart';

/// One real training session ("what actually happened").
class WorkoutSession extends Equatable {
  const WorkoutSession({
    required this.id,
    required this.programId,
    required this.workoutDayId,
    required this.workoutName,
    required this.startedAt,
    required this.status,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String programId;
  final String workoutDayId;

  /// Snapshot so renaming a day never rewrites history.
  final String workoutName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final SessionStatus status;
  final String? notes;

  bool get isInProgress => status == SessionStatus.inProgress;
  bool get isCompleted => status == SessionStatus.completed;

  WorkoutSession copyWith({
    SessionStatus? status,
    DateTime? completedAt,
    String? notes,
  }) {
    return WorkoutSession(
      id: id,
      programId: programId,
      workoutDayId: workoutDayId,
      workoutName: workoutName,
      startedAt: startedAt,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    programId,
    workoutDayId,
    workoutName,
    startedAt,
    completedAt,
    status,
    notes,
  ];
}

/// Snapshot of a program exercise as it was when the session started, so a
/// future program edit does not change the meaning of an old workout.
class SessionExercise extends Equatable {
  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.programExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.primaryMuscle,
    required this.category,
    required this.orderIndex,
    required this.targetSets,
    required this.repMin,
    required this.repMax,
    required this.restSeconds,
    required this.rirMin,
    required this.rirMax,
    required this.weightStep,
    this.supersetGroup,
    this.isSkipped = false,
  });

  final String id;
  final String sessionId;
  final String programExerciseId;
  final String exerciseId;
  final String exerciseName;
  final MuscleGroup primaryMuscle;
  final ExerciseCategory category;
  final int orderIndex;
  final int targetSets;
  final int repMin;
  final int repMax;
  final int restSeconds;
  final int rirMin;
  final int rirMax;
  final double weightStep;
  final int? supersetGroup;
  final bool isSkipped;

  SessionExercise copyWith({bool? isSkipped, double? weightStep}) {
    return SessionExercise(
      id: id,
      sessionId: sessionId,
      programExerciseId: programExerciseId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      primaryMuscle: primaryMuscle,
      category: category,
      orderIndex: orderIndex,
      targetSets: targetSets,
      repMin: repMin,
      repMax: repMax,
      restSeconds: restSeconds,
      rirMin: rirMin,
      rirMax: rirMax,
      weightStep: weightStep ?? this.weightStep,
      supersetGroup: supersetGroup,
      isSkipped: isSkipped ?? this.isSkipped,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    programExerciseId,
    exerciseId,
    exerciseName,
    primaryMuscle,
    category,
    orderIndex,
    targetSets,
    repMin,
    repMax,
    restSeconds,
    rirMin,
    rirMax,
    weightStep,
    supersetGroup,
    isSkipped,
  ];
}

/// Exact performance of one set. Every completed set is persisted immediately.
class SetLog extends Equatable {
  const SetLog({
    required this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    required this.plannedRepsMin,
    required this.plannedRepsMax,
    required this.actualWeight,
    required this.actualReps,
    required this.completedAt,
    this.plannedWeight,
    this.rir,
    this.isWarmup = false,
    this.notes,
  });

  final String id;
  final String sessionExerciseId;
  final int setNumber;
  final int plannedRepsMin;
  final int plannedRepsMax;
  final double? plannedWeight;
  final double actualWeight;
  final int actualReps;
  final int? rir;
  final DateTime completedAt;
  final bool isWarmup;
  final String? notes;

  @override
  List<Object?> get props => [
    id,
    sessionExerciseId,
    setNumber,
    plannedRepsMin,
    plannedRepsMax,
    plannedWeight,
    actualWeight,
    actualReps,
    rir,
    completedAt,
    isWarmup,
    notes,
  ];
}
