import '../../domain/entities/workout_session.dart';
import '../../domain/training/performance.dart';

/// An in-memory index of all workout records, built in a single pass over
/// each box.
///
/// Queries that span many sessions (history, progress, the dashboard) use
/// one snapshot, so their cost grows linearly with stored data instead of
/// re-scanning every box once per session.
class WorkoutIndex {
  WorkoutIndex.build({
    required Iterable<WorkoutSession> sessions,
    required Iterable<SessionExercise> sessionExercises,
    required Iterable<SetLog> setLogs,
  }) {
    for (final s in sessions) {
      _sessions[s.id] = s;
    }
    for (final e in sessionExercises) {
      _exercisesBySession.putIfAbsent(e.sessionId, () => []).add(e);
      _exercisesByExerciseId.putIfAbsent(e.exerciseId, () => []).add(e);
    }
    for (final list in _exercisesBySession.values) {
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }
    for (final set in setLogs) {
      _setsByExercise.putIfAbsent(set.sessionExerciseId, () => []).add(set);
    }
    for (final list in _setsByExercise.values) {
      list.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }
  }

  final _sessions = <String, WorkoutSession>{};
  final _exercisesBySession = <String, List<SessionExercise>>{};
  final _exercisesByExerciseId = <String, List<SessionExercise>>{};
  final _setsByExercise = <String, List<SetLog>>{};

  WorkoutSession? session(String id) => _sessions[id];

  /// Ordered by `orderIndex`.
  List<SessionExercise> exercisesOf(String sessionId) =>
      List.unmodifiable(_exercisesBySession[sessionId] ?? const []);

  /// Ordered by set number.
  List<SetLog> setsOfExercise(String sessionExerciseId) =>
      List.unmodifiable(_setsByExercise[sessionExerciseId] ?? const []);

  /// Grouped by exercise order, then by set number.
  List<SetLog> setsOf(String sessionId) => [
    for (final e in _exercisesBySession[sessionId] ?? const <SessionExercise>[])
      ...?_setsByExercise[e.id],
  ];

  /// Working-set performance of [exerciseId] in completed sessions, most
  /// recent first.
  List<ExerciseSessionPerformance> performances(
    String exerciseId, {
    String? excludeSessionId,
    int? limit,
  }) {
    final result = <ExerciseSessionPerformance>[];
    for (final exercise in _exercisesByExerciseId[exerciseId] ?? const []) {
      final session = _sessions[exercise.sessionId];
      if (session == null || !session.isCompleted) continue;
      if (session.id == excludeSessionId) continue;
      final sets = (_setsByExercise[exercise.id] ?? const <SetLog>[])
          .where((s) => !s.isWarmup)
          .toList();
      if (sets.isEmpty) continue;
      result.add(
        ExerciseSessionPerformance(
          sessionId: session.id,
          date: session.completedAt ?? session.startedAt,
          sets: [
            for (final s in sets)
              SetPerformance(
                weight: s.actualWeight,
                reps: s.actualReps,
                rir: s.rir,
              ),
          ],
        ),
      );
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return limit == null ? result : result.take(limit).toList();
  }
}
