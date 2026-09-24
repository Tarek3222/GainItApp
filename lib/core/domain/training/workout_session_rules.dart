import 'package:equatable/equatable.dart';

import '../entities/enums.dart';
import '../entities/workout_session.dart';

enum SessionAction { logSet, skipExercise, complete, abandon }

class WorkoutProgress extends Equatable {
  const WorkoutProgress({required this.completedSets, required this.totalSets});

  final int completedSets;
  final int totalSets;

  bool get isDone => totalSets > 0 && completedSets >= totalSets;

  double get fraction =>
      totalSets == 0 ? 0 : (completedSets / totalSets).clamp(0, 1).toDouble();

  @override
  List<Object?> get props => [completedSets, totalSets];
}

/// Workout state machine (spec §14):
/// `InProgress → (log / skip)* → Completed | Abandoned`.
abstract final class WorkoutSessionRules {
  static bool isAllowed(SessionStatus status, SessionAction action) {
    return switch (status) {
      SessionStatus.inProgress => true,
      SessionStatus.completed || SessionStatus.abandoned => false,
    };
  }

  static SessionStatus transition(SessionStatus status, SessionAction action) {
    if (!isAllowed(status, action)) {
      throw StateError('Cannot ${action.name} a ${status.name} workout.');
    }
    return switch (action) {
      SessionAction.logSet || SessionAction.skipExercise => status,
      SessionAction.complete => SessionStatus.completed,
      SessionAction.abandon => SessionStatus.abandoned,
    };
  }

  /// Working sets done vs planned. Skipped exercises only count what was
  /// actually logged before skipping.
  static WorkoutProgress progress(
    List<SessionExercise> exercises,
    List<SetLog> sets,
  ) {
    var total = 0;
    var completed = 0;
    for (final exercise in exercises) {
      final done = sets
          .where((s) => s.sessionExerciseId == exercise.id && !s.isWarmup)
          .length;
      final planned = exercise.isSkipped
          ? done
          : (done > exercise.targetSets ? done : exercise.targetSets);
      total += planned;
      completed += done;
    }
    return WorkoutProgress(completedSets: completed, totalSets: total);
  }

  static int nextSetNumber(String sessionExerciseId, List<SetLog> sets) {
    final numbers = sets
        .where((s) => s.sessionExerciseId == sessionExerciseId)
        .map((s) => s.setNumber);
    return numbers.isEmpty ? 1 : numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Index of the exercise to do next, or `null` when everything is done.
  ///
  /// Normally this is the first exercise with sets remaining. Inside a
  /// superset it alternates: the unfinished member with the fewest logged
  /// sets comes next (ties go to the earlier exercise), so A1 → B1 → A2 → B2.
  static int? currentExerciseIndex(
    List<SessionExercise> exercises,
    List<SetLog> sets,
  ) {
    int done(SessionExercise e) =>
        sets.where((s) => s.sessionExerciseId == e.id && !s.isWarmup).length;
    bool unfinished(SessionExercise e) =>
        !e.isSkipped && done(e) < e.targetSets;

    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      if (!unfinished(exercise)) continue;
      final group = exercise.supersetGroup;
      if (group == null) return i;

      var best = i;
      for (var j = i + 1; j < exercises.length; j++) {
        final other = exercises[j];
        if (other.supersetGroup == group &&
            unfinished(other) &&
            done(other) < done(exercises[best])) {
          best = j;
        }
      }
      return best;
    }
    return null;
  }

  /// A workout left open this long after its last activity is treated as
  /// forgotten when it is finally closed.
  static const staleAfter = Duration(hours: 3);

  /// When a workout counts as finished.
  ///
  /// - Normally `now`.
  /// - For a forgotten session, the time of the last logged set (or the start
  ///   time when nothing was logged). This way a workout from last Sunday
  ///   isn't credited to the day it is closed and doesn't report a week-long
  ///   duration.
  /// - Never earlier than [startedAt], even if the device clock went
  ///   backwards.
  static DateTime completionTime({
    required DateTime startedAt,
    required DateTime now,
    DateTime? lastSetAt,
  }) {
    final lastActivity = lastSetAt ?? startedAt;
    var at = now.difference(lastActivity) > staleAfter ? lastActivity : now;
    if (at.isBefore(startedAt)) at = startedAt;
    return at;
  }
}
