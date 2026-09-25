import '../domain/entities/enums.dart';
import 'hive_storage.dart';

/// Repairs the only inconsistencies that ordered writes can leave behind:
/// - children whose parent was never written or was only partly removed
///   (a crash mid-write), and
/// - more than one in-progress workout. Only the newest is kept open; the
///   older ones are abandoned so they can't linger unseen.
class StorageIntegrityCheck {
  const StorageIntegrityCheck(this._storage);

  final HiveStorage _storage;

  /// Returns the number of repaired records.
  Future<int> run() async {
    final sessionIds = _storage.sessions.keys.toSet();
    final orphanExercises = _storage.sessionExercises.values
        .where((e) => !sessionIds.contains(e.sessionId))
        .map((e) => e.id)
        .toList();
    await _storage.sessionExercises.deleteAll(orphanExercises);

    final exerciseIds = _storage.sessionExercises.keys.toSet();
    final orphanSets = _storage.setLogs.values
        .where((s) => !exerciseIds.contains(s.sessionExerciseId))
        .map((s) => s.id)
        .toList();
    await _storage.setLogs.deleteAll(orphanSets);

    final goalIds = _storage.dailyGoals.keys.toSet();
    final orphanGoalLogs = _storage.dailyGoalLogs.values
        .where((l) => !goalIds.contains(l.goalId))
        .map((l) => l.id)
        .toList();
    await _storage.dailyGoalLogs.deleteAll(orphanGoalLogs);

    final inProgress =
        _storage.sessions.values.where((s) => s.isInProgress).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final stale = inProgress.skip(1).toList();
    await _storage.sessions.putAll({
      for (final s in stale)
        s.id: s.copyWith(
          status: SessionStatus.abandoned,
          completedAt: s.startedAt,
        ),
    });

    return orphanExercises.length +
        orphanSets.length +
        orphanGoalLogs.length +
        stale.length;
  }
}
