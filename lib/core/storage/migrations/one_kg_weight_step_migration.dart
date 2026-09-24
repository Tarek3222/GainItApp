import '../hive_storage.dart';

/// v2: weights move in 1 kg steps instead of 2 / 2.5 kg. Rewrites every
/// program exercise and the exercises of an in-progress session; finished
/// sessions keep their original snapshot. Only `weightStep` changes, to a
/// positive constant, so the records stay valid without re-running the
/// validators.
Future<void> migrateToOneKgWeightStep(HiveStorage storage) async {
  const step = 1.0;

  final programExercises = {
    for (final e in storage.programExercises.values)
      if (e.weightStep != step) e.id: e.copyWith(weightStep: step),
  };
  if (programExercises.isNotEmpty) {
    await storage.programExercises.putAll(programExercises);
  }

  final activeSessionIds = {
    for (final s in storage.sessions.values)
      if (s.isInProgress) s.id,
  };
  final sessionExercises = {
    for (final e in storage.sessionExercises.values)
      if (activeSessionIds.contains(e.sessionId) && e.weightStep != step)
        e.id: e.copyWith(weightStep: step),
  };
  if (sessionExercises.isNotEmpty) {
    await storage.sessionExercises.putAll(sessionExercises);
  }
}
