import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';

/// A stored session with everything logged in it.
class SessionRecord extends Equatable {
  const SessionRecord({
    required this.session,
    required this.exercises,
    required this.sets,
  });

  final WorkoutSession session;
  final List<SessionExercise> exercises;
  final List<SetLog> sets;

  @override
  List<Object?> get props => [session, exercises, sets];
}

class HistoryFilter extends Equatable {
  const HistoryFilter({this.muscle, this.exerciseId, this.from, this.to});

  final MuscleGroup? muscle;
  final String? exerciseId;

  /// Inclusive start day.
  final DateTime? from;

  /// Inclusive end day.
  final DateTime? to;

  bool get isEmpty =>
      muscle == null && exerciseId == null && from == null && to == null;

  bool matches(SessionRecord record) {
    final date = record.session.completedAt ?? record.session.startedAt;
    if (from != null && date.isBefore(_startOfDay(from!))) return false;
    if (to != null &&
        !date.isBefore(_startOfDay(to!).add(const Duration(days: 1)))) {
      return false;
    }
    final performed = record.exercises.where(
      (e) => record.sets.any((s) => s.sessionExerciseId == e.id),
    );
    if (muscle != null && !performed.any((e) => e.primaryMuscle == muscle)) {
      return false;
    }
    if (exerciseId != null &&
        !performed.any((e) => e.exerciseId == exerciseId)) {
      return false;
    }
    return true;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  HistoryFilter copyWith({
    MuscleGroup? Function()? muscle,
    String? Function()? exerciseId,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) {
    return HistoryFilter(
      muscle: muscle == null ? this.muscle : muscle(),
      exerciseId: exerciseId == null ? this.exerciseId : exerciseId(),
      from: from == null ? this.from : from(),
      to: to == null ? this.to : to(),
    );
  }

  @override
  List<Object?> get props => [muscle, exerciseId, from, to];
}

class HistoryItem extends Equatable {
  const HistoryItem({
    required this.sessionId,
    required this.workoutName,
    required this.date,
    required this.duration,
    required this.workingSets,
    required this.muscles,
  });

  final String sessionId;
  final String workoutName;
  final DateTime date;
  final Duration duration;
  final int workingSets;
  final List<MuscleGroup> muscles;

  @override
  List<Object?> get props => [
    sessionId,
    workoutName,
    date,
    duration,
    workingSets,
    muscles,
  ];
}

class HistoryData extends Equatable {
  const HistoryData({
    required this.items,
    required this.exerciseOptions,
    required this.filter,
    required this.totalSessions,
  });

  final List<HistoryItem> items;

  /// Exercises that appear in history (for the exercise filter).
  final List<({String id, String name})> exerciseOptions;
  final HistoryFilter filter;
  final int totalSessions;

  @override
  List<Object?> get props => [items, exerciseOptions, filter, totalSessions];
}

class SessionDetailExercise extends Equatable {
  const SessionDetailExercise({
    required this.exerciseId,
    required this.name,
    required this.muscle,
    required this.sets,
    required this.skipped,
  });

  final String exerciseId;
  final String name;
  final MuscleGroup muscle;
  final List<SetLog> sets;
  final bool skipped;

  @override
  List<Object?> get props => [exerciseId, name, muscle, sets, skipped];
}

class SessionDetail extends Equatable {
  const SessionDetail({
    required this.sessionId,
    required this.workoutName,
    required this.date,
    required this.duration,
    required this.workingSets,
    required this.exercises,
    this.notes,
  });

  final String sessionId;
  final String workoutName;
  final DateTime date;
  final Duration duration;
  final int workingSets;
  final List<SessionDetailExercise> exercises;
  final String? notes;

  @override
  List<Object?> get props => [
    sessionId,
    workoutName,
    date,
    duration,
    workingSets,
    exercises,
    notes,
  ];
}
