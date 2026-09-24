import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/domain/training/performance.dart';
import '../../../../core/domain/training/progression_engine.dart';
import '../../../../core/domain/training/schedule_resolver.dart';

/// Raw data for the weekly plan.
class WeekPlanData extends Equatable {
  const WeekPlanData({
    required this.program,
    required this.days,
    required this.dayExercises,
    required this.completedSessions,
  });

  final Program program;
  final List<WorkoutDay> days;
  final Map<String, List<ProgramExercise>> dayExercises;
  final List<WorkoutSession> completedSessions;

  @override
  List<Object?> get props => [program, days, dayExercises, completedSessions];
}

class PlanDay extends Equatable {
  const PlanDay({
    required this.day,
    required this.status,
    required this.date,
    required this.exerciseCount,
    required this.totalSets,
    this.lastCompletedAt,
  });

  final WorkoutDay day;
  final DayStatus status;
  final DateTime date;
  final int exerciseCount;
  final int totalSets;
  final DateTime? lastCompletedAt;

  @override
  List<Object?> get props => [
    day,
    status,
    date,
    exerciseCount,
    totalSets,
    lastCompletedAt,
  ];
}

class WeeklyPlan extends Equatable {
  const WeeklyPlan({
    required this.programName,
    required this.weekNumber,
    required this.days,
    required this.completedWorkouts,
    required this.plannedWorkouts,
  });

  final String programName;
  final int weekNumber;
  final List<PlanDay> days;
  final int completedWorkouts;
  final int plannedWorkouts;

  @override
  List<Object?> get props => [
    programName,
    weekNumber,
    days,
    completedWorkouts,
    plannedWorkouts,
  ];
}

/// Raw data for one workout day.
class WorkoutDayData extends Equatable {
  const WorkoutDayData({
    required this.day,
    required this.items,
    this.lastCompletedAt,
    this.activeSessionDayId,
  });

  final WorkoutDay day;
  final List<
    ({
      ProgramExercise config,
      Exercise exercise,
      List<ExerciseSessionPerformance> history,
    })
  >
  items;
  final DateTime? lastCompletedAt;

  /// Day of the in-progress workout, if any.
  final String? activeSessionDayId;

  @override
  List<Object?> get props => [day, items, lastCompletedAt, activeSessionDayId];
}

class OverviewExercise extends Equatable {
  const OverviewExercise({
    required this.exerciseId,
    required this.name,
    required this.primaryMuscle,
    required this.config,
    required this.recommendation,
    this.lastPerformance,
  });

  final String exerciseId;
  final String name;
  final MuscleGroup primaryMuscle;
  final ProgramExercise config;
  final Recommendation recommendation;
  final ExerciseSessionPerformance? lastPerformance;

  @override
  List<Object?> get props => [
    exerciseId,
    name,
    primaryMuscle,
    config,
    recommendation,
    lastPerformance,
  ];
}

class WorkoutOverview extends Equatable {
  const WorkoutOverview({
    required this.day,
    required this.exercises,
    required this.totalSets,
    required this.plannedVolume,
    required this.isInProgress,
    this.lastCompletedAt,
  });

  final WorkoutDay day;
  final List<OverviewExercise> exercises;
  final int totalSets;
  final Map<MuscleGroup, int> plannedVolume;
  final bool isInProgress;
  final DateTime? lastCompletedAt;

  @override
  List<Object?> get props => [
    day,
    exercises,
    totalSets,
    plannedVolume,
    isInProgress,
    lastCompletedAt,
  ];
}
