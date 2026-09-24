import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/domain/training/performance_comparator.dart';

class WorkoutSummaryData extends Equatable {
  const WorkoutSummaryData({
    required this.session,
    required this.exercises,
    required this.sets,
    required this.previous,
  });

  final WorkoutSession session;
  final List<SessionExercise> exercises;
  final List<SetLog> sets;

  /// The previous completed performance per exerciseId (if any).
  final Map<String, ExerciseSessionPerformance> previous;

  @override
  List<Object?> get props => [session, exercises, sets, previous];
}

class ExerciseProgressLine extends Equatable {
  const ExerciseProgressLine({
    required this.exerciseId,
    required this.exerciseName,
    required this.current,
    required this.comparison,
    this.previous,
  });

  final String exerciseId;
  final String exerciseName;
  final ExerciseSessionPerformance current;
  final ExerciseSessionPerformance? previous;
  final PerformanceComparison comparison;

  @override
  List<Object?> get props => [
    exerciseId,
    exerciseName,
    current,
    previous,
    comparison,
  ];
}

class WorkoutSummary extends Equatable {
  const WorkoutSummary({
    required this.sessionId,
    required this.workoutName,
    required this.duration,
    required this.workingSets,
    required this.volume,
    required this.lines,
  });

  final String sessionId;
  final String workoutName;
  final Duration duration;
  final int workingSets;
  final Map<MuscleGroup, int> volume;
  final List<ExerciseProgressLine> lines;

  @override
  List<Object?> get props => [
    sessionId,
    workoutName,
    duration,
    workingSets,
    volume,
    lines,
  ];
}
