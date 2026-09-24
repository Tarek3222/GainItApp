import '../../../../core/domain/entities/enums.dart';
import '../../../../core/result/api_result.dart';
import '../entities/history_entities.dart';
import '../repositories/history_repository.dart';

class WatchHistoryUseCase {
  const WatchHistoryUseCase(this._repository);

  final HistoryRepository _repository;

  Stream<ApiResult<HistoryData>> call(HistoryFilter filter) => _repository
      .watchCompletedSessions()
      .map((r) => r.map((records) => build(records, filter)));

  static HistoryData build(List<SessionRecord> records, HistoryFilter filter) {
    final options = <String, String>{};
    for (final record in records) {
      for (final e in record.exercises) {
        options.putIfAbsent(e.exerciseId, () => e.exerciseName);
      }
    }
    final sortedOptions = [
      for (final e in options.entries) (id: e.key, name: e.value),
    ]..sort((a, b) => a.name.compareTo(b.name));

    return HistoryData(
      items: [
        for (final record in records)
          if (filter.matches(record)) toItem(record),
      ],
      exerciseOptions: sortedOptions,
      filter: filter,
      totalSessions: records.length,
    );
  }

  static HistoryItem toItem(SessionRecord record) {
    final session = record.session;
    final working = record.sets.where((s) => !s.isWarmup).toList();
    final loggedIds = working.map((s) => s.sessionExerciseId).toSet();
    final muscles = <MuscleGroup>{
      for (final e in record.exercises)
        if (loggedIds.contains(e.id)) e.primaryMuscle,
    }.toList()..sort((a, b) => a.index.compareTo(b.index));
    final end = session.completedAt ?? session.startedAt;
    return HistoryItem(
      sessionId: session.id,
      workoutName: session.workoutName,
      date: end,
      duration: end.difference(session.startedAt),
      workingSets: working.length,
      muscles: muscles,
    );
  }
}

class GetSessionDetailUseCase {
  const GetSessionDetailUseCase(this._repository);

  final HistoryRepository _repository;

  Future<ApiResult<SessionDetail>> call(String sessionId) async {
    final result = await _repository.getSession(sessionId);
    return result.map(build);
  }

  static SessionDetail build(SessionRecord record) {
    final item = WatchHistoryUseCase.toItem(record);
    return SessionDetail(
      sessionId: item.sessionId,
      workoutName: item.workoutName,
      date: item.date,
      duration: item.duration,
      workingSets: item.workingSets,
      notes: record.session.notes,
      exercises: [
        for (final e in record.exercises)
          SessionDetailExercise(
            exerciseId: e.exerciseId,
            name: e.exerciseName,
            muscle: e.primaryMuscle,
            skipped: e.isSkipped,
            sets: record.sets.where((s) => s.sessionExerciseId == e.id).toList()
              ..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
          ),
      ],
    );
  }
}
