import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/body_weight_trend.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/domain/training/performance_comparator.dart';

typedef ExercisePerformancePair = ({
  String exerciseId,
  String name,
  ExerciseSessionPerformance current,
  ExerciseSessionPerformance? previous,
});

/// Raw data the dashboard is computed from.
class HomeData extends Equatable {
  const HomeData({
    required this.program,
    required this.days,
    required this.plannedSetsPerDay,
    required this.exerciseCountPerDay,
    required this.completedSessions,
    required this.workingSetsPerSession,
    required this.weights,
    required this.lastSessionExercises,
    this.profile,
    this.activeSession,
  });

  final UserProfile? profile;
  final Program program;
  final List<WorkoutDay> days;
  final Map<String, int> plannedSetsPerDay;
  final Map<String, int> exerciseCountPerDay;

  /// Most recent first.
  final List<WorkoutSession> completedSessions;
  final Map<String, int> workingSetsPerSession;
  final List<BodyWeightEntry> weights;

  /// Exercises of the most recent completed session with the previous
  /// performance of each.
  final List<ExercisePerformancePair> lastSessionExercises;
  final WorkoutSession? activeSession;

  @override
  List<Object?> get props => [
    profile,
    program,
    days,
    plannedSetsPerDay,
    exerciseCountPerDay,
    completedSessions,
    workingSetsPerSession,
    weights,
    lastSessionExercises,
    activeSession,
  ];
}

class NextWorkoutInfo extends Equatable {
  const NextWorkoutInfo({
    required this.dayId,
    required this.name,
    required this.date,
    required this.isToday,
    required this.exerciseCount,
    required this.totalSets,
  });

  final String dayId;
  final String name;
  final DateTime date;
  final bool isToday;
  final int exerciseCount;
  final int totalSets;

  @override
  List<Object?> get props => [
    dayId,
    name,
    date,
    isToday,
    exerciseCount,
    totalSets,
  ];
}

class HomeProgress extends Equatable {
  const HomeProgress({
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

/// Part of the day, for the greeting.
enum GreetingTime { morning, afternoon, evening }

class HomeDashboard extends Equatable {
  const HomeDashboard({
    required this.greeting,
    required this.name,
    required this.weekNumber,
    required this.programName,
    required this.weekCompletedWorkouts,
    required this.weekPlannedWorkouts,
    required this.weekWorkingSets,
    this.nextWorkout,
    this.activeSessionId,
    this.activeWorkoutName,
    this.bodyWeight,
    this.lastProgress,
  });

  final GreetingTime greeting;
  final String name;
  final int weekNumber;
  final String programName;
  final NextWorkoutInfo? nextWorkout;
  final String? activeSessionId;
  final String? activeWorkoutName;
  final BodyWeightSummary? bodyWeight;
  final int weekCompletedWorkouts;
  final int weekPlannedWorkouts;
  final int weekWorkingSets;
  final HomeProgress? lastProgress;

  @override
  List<Object?> get props => [
    greeting,
    name,
    weekNumber,
    programName,
    nextWorkout,
    activeSessionId,
    activeWorkoutName,
    bodyWeight,
    weekCompletedWorkouts,
    weekPlannedWorkouts,
    weekWorkingSets,
    lastProgress,
  ];
}
