import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/training/body_weight_trend.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/domain/training/volume_calculator.dart';

typedef ExerciseRef = ({String id, String name, MuscleGroup muscle});

/// Raw data for the progress dashboard.
class ProgressData extends Equatable {
  const ProgressData({
    required this.weights,
    required this.loggedSets,
    required this.plannedConfig,
    required this.exercisesWithHistory,
  });

  final List<BodyWeightEntry> weights;

  /// All logged sets of completed sessions (the use case filters by date).
  final List<VolumeSetEntry> loggedSets;
  final List<({MuscleGroup muscle, int sets})> plannedConfig;
  final List<ExerciseRef> exercisesWithHistory;

  @override
  List<Object?> get props => [
    weights,
    loggedSets,
    plannedConfig,
    exercisesWithHistory,
  ];
}

class MuscleVolume extends Equatable {
  const MuscleVolume({
    required this.muscle,
    required this.done,
    required this.planned,
  });

  final MuscleGroup muscle;
  final int done;
  final int planned;

  double get fraction => planned == 0 ? 0 : (done / planned).clamp(0, 1);

  @override
  List<Object?> get props => [muscle, done, planned];
}

class ProgressDashboard extends Equatable {
  const ProgressDashboard({
    required this.weightPoints,
    required this.weightTrend,
    required this.weeklyVolume,
    required this.exercises,
    this.bodyWeight,
  });

  final List<WeightPoint> weightPoints;
  final List<WeightPoint> weightTrend;
  final BodyWeightSummary? bodyWeight;
  final List<MuscleVolume> weeklyVolume;
  final List<ExerciseRef> exercises;

  @override
  List<Object?> get props => [
    weightPoints,
    weightTrend,
    bodyWeight,
    weeklyVolume,
    exercises,
  ];
}

class ExerciseHistoryData extends Equatable {
  const ExerciseHistoryData({required this.exercise, required this.sessions});

  final ExerciseRef exercise;

  /// Most recent first.
  final List<ExerciseSessionPerformance> sessions;

  @override
  List<Object?> get props => [exercise, sessions];
}

class ExerciseTrendPoint extends Equatable {
  const ExerciseTrendPoint({
    required this.date,
    required this.topWeight,
    required this.totalReps,
    required this.volumeLoad,
    required this.estimatedOneRepMax,
  });

  final DateTime date;
  final double topWeight;
  final int totalReps;
  final double volumeLoad;
  final double estimatedOneRepMax;

  @override
  List<Object?> get props => [
    date,
    topWeight,
    totalReps,
    volumeLoad,
    estimatedOneRepMax,
  ];
}

class ExerciseProgress extends Equatable {
  const ExerciseProgress({
    required this.exercise,
    required this.sessions,
    required this.trend,
    this.bestWeight,
    this.bestReps,
    this.bestOneRepMax,
  });

  final ExerciseRef exercise;
  final double? bestWeight;

  /// Most reps in one set.
  final int? bestReps;
  final double? bestOneRepMax;

  /// Most recent first.
  final List<ExerciseSessionPerformance> sessions;

  /// Oldest first.
  final List<ExerciseTrendPoint> trend;

  bool get isEmpty => sessions.isEmpty;

  @override
  List<Object?> get props => [
    exercise,
    bestWeight,
    bestReps,
    bestOneRepMax,
    sessions,
    trend,
  ];
}
