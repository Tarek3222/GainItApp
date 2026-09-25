import '../../domain/entities/enums.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/training/performance.dart';
import '../../domain/training/workout_session_rules.dart';
import '../../domain/validation/validators.dart';
import '../../errors/exceptions.dart';
import '../hive_storage.dart';
import '../storage_guard.dart';
import 'program_local_data_source.dart';
import 'workout_index.dart';

/// Sessions, their exercise snapshots and set logs.
///
/// Hive has no transactions, so multi-box writes are ordered so that a crash
/// leaves at most orphaned children, which `StorageIntegrityCheck` removes.
class WorkoutLocalDataSource {
  WorkoutLocalDataSource(this._storage, this._programs);

  final HiveStorage _storage;
  final ProgramLocalDataSource _programs;

  /// In-flight `startSession`, used to serialise starts. Otherwise two quick
  /// taps could both pass the "no active workout" check.
  Future<WorkoutSession>? _starting;

  /// One linear pass over every workout box. Use a single snapshot for
  /// queries that touch many sessions.
  WorkoutIndex snapshot() => WorkoutIndex.build(
    sessions: _storage.sessions.values,
    sessionExercises: _storage.sessionExercises.values,
    setLogs: _storage.setLogs.values,
  );

  WorkoutSession? session(String id) => _storage.sessions.get(id);

  WorkoutSession requireSession(String id) =>
      session(id) ?? (throw NotFoundException('Workout $id not found.'));

  WorkoutSession? activeSession() {
    final active = sessions(status: SessionStatus.inProgress);
    return active.isEmpty ? null : active.first;
  }

  /// Most recent first.
  List<WorkoutSession> sessions({SessionStatus? status}) {
    final list = _storage.sessions.values
        .where((s) => status == null || s.status == status)
        .toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  List<SessionExercise> exercisesOf(String sessionId) =>
      _storage.sessionExercises.values
          .where((e) => e.sessionId == sessionId)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  /// Grouped by exercise order, then set number.
  List<SetLog> setsOf(String sessionId) {
    final exercises = exercisesOf(sessionId);
    final order = {for (final (i, e) in exercises.indexed) e.id: i};
    return _storage.setLogs.values
        .where((s) => order.containsKey(s.sessionExerciseId))
        .toList()
      ..sort((a, b) {
        final byExercise = order[a.sessionExerciseId]!.compareTo(
          order[b.sessionExerciseId]!,
        );
        return byExercise != 0
            ? byExercise
            : a.setNumber.compareTo(b.setNumber);
      });
  }

  /// Snapshots the day's configuration into a new in-progress session.
  /// Starting the day that is already in progress returns that session.
  Future<WorkoutSession> startSession({
    required String dayId,
    required DateTime now,
    required String Function() newId,
  }) async {
    while (_starting != null) {
      try {
        await _starting;
      } on Object {
        // The earlier start's caller handles its own error.
      }
    }
    final future = _startSession(dayId: dayId, now: now, newId: newId);
    _starting = future;
    try {
      return await future;
    } finally {
      if (identical(_starting, future)) _starting = null;
    }
  }

  Future<WorkoutSession> _startSession({
    required String dayId,
    required DateTime now,
    required String Function() newId,
  }) async {
    final active = activeSession();
    if (active != null) {
      if (active.workoutDayId == dayId) return active;
      throw const InvalidStateException('errors.workoutInProgress');
    }
    final day = _programs.requireDay(dayId);
    if (!day.isWorkout) {
      throw const InvalidStateException('errors.restDay');
    }
    final program = _programs.requireActiveProgram();
    final configs = _programs.programExercisesForDay(dayId);
    if (configs.isEmpty) {
      throw const InvalidStateException('errors.noExercises');
    }

    final session = WorkoutSession(
      id: newId(),
      programId: program.id,
      workoutDayId: day.id,
      workoutName: day.name,
      startedAt: now,
      status: SessionStatus.inProgress,
    );
    final snapshots = <SessionExercise>[
      for (final config in configs) _snapshot(session.id, config, newId()),
    ];
    for (final snapshot in snapshots) {
      ensureValid(Validators.sessionExercise(snapshot));
    }

    // Children first, parent last.
    await _storage.sessionExercises.putAll({
      for (final s in snapshots) s.id: s,
    });
    await _storage.sessions.put(session.id, session);
    return session;
  }

  SessionExercise _snapshot(
    String sessionId,
    ProgramExercise config,
    String id,
  ) {
    final exercise =
        _programs.exercise(config.exerciseId) ??
        (throw NotFoundException('Exercise ${config.exerciseId} not found.'));
    return SessionExercise(
      id: id,
      sessionId: sessionId,
      programExerciseId: config.id,
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      primaryMuscle: exercise.primaryMuscle,
      category: exercise.category,
      orderIndex: config.orderIndex,
      targetSets: config.workingSets,
      repMin: config.repMin,
      repMax: config.repMax,
      restSeconds: config.restMinSeconds,
      rirMin: config.rirMin,
      rirMax: config.rirMax,
      weightStep: config.weightStep,
      supersetGroup: config.supersetGroup,
    );
  }

  /// Applies the workout state machine; throws when [action] is not allowed.
  SessionStatus _transition(WorkoutSession session, SessionAction action) {
    if (!WorkoutSessionRules.isAllowed(session.status, action)) {
      throw const InvalidStateException('errors.workoutFinished');
    }
    return WorkoutSessionRules.transition(session.status, action);
  }

  SessionExercise _requireExercise(String sessionExerciseId) =>
      _storage.sessionExercises.get(sessionExerciseId) ??
      (throw const NotFoundException('Exercise not found in workout.'));

  /// Autosave: one completed set = one `put`.
  Future<void> saveSet(SetLog set) async {
    final exercise = _requireExercise(set.sessionExerciseId);
    _transition(requireSession(exercise.sessionId), SessionAction.logSet);
    ensureValid(Validators.setLog(set));
    await _storage.setLogs.put(set.id, set);
  }

  /// Undo. Only the most recent set of an exercise can be removed, which
  /// keeps set numbers contiguous.
  Future<void> deleteSet(String setId) async {
    final set = _storage.setLogs.get(setId);
    if (set == null) return;
    final exercise = _requireExercise(set.sessionExerciseId);
    _transition(requireSession(exercise.sessionId), SessionAction.logSet);
    final latest = _storage.setLogs.values
        .where((s) => s.sessionExerciseId == exercise.id)
        .fold<int>(0, (max, s) => s.setNumber > max ? s.setNumber : max);
    if (set.setNumber != latest) {
      throw const InvalidStateException('errors.onlyLastSetUndo');
    }
    await _storage.setLogs.delete(setId);
  }

  Future<void> setSkipped(
    String sessionExerciseId, {
    required bool skipped,
  }) async {
    final exercise = _requireExercise(sessionExerciseId);
    _transition(requireSession(exercise.sessionId), SessionAction.skipExercise);
    await _storage.sessionExercises.put(
      exercise.id,
      exercise.copyWith(isSkipped: skipped),
    );
  }

  /// Completes or abandons a workout. The finish time follows
  /// [WorkoutSessionRules.completionTime]: a forgotten session is dated at its
  /// last activity, and the time never falls before the start.
  Future<WorkoutSession> finish(
    String sessionId, {
    required SessionStatus status,
    required DateTime at,
  }) async {
    final current = requireSession(sessionId);
    _transition(
      current,
      status == SessionStatus.completed
          ? SessionAction.complete
          : SessionAction.abandon,
    );
    final sets = setsOf(sessionId);
    final lastSetAt = sets.isEmpty
        ? null
        : sets.map((s) => s.completedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final updated = current.copyWith(
      status: status,
      completedAt: WorkoutSessionRules.completionTime(
        startedAt: current.startedAt,
        now: at,
        lastSetAt: lastSetAt,
      ),
    );
    ensureValid(Validators.session(updated));
    await _storage.sessions.put(updated.id, updated);
    return updated;
  }

  /// See [WorkoutIndex.performances].
  List<ExerciseSessionPerformance> performances(
    String exerciseId, {
    String? excludeSessionId,
    int? limit,
  }) => snapshot().performances(
    exerciseId,
    excludeSessionId: excludeSessionId,
    limit: limit,
  );

  List<ChangeTrigger> get triggers => [
    _storage.sessions.watch,
    _storage.sessionExercises.watch,
    _storage.setLogs.watch,
  ];

  Stream<T> watch<T>(T Function() query) => watchTriggers(triggers, query);
}
