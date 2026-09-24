import '../../../../core/domain/entities/enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/local_data_sources/workout_index.dart';
import '../../../../core/storage/local_data_sources/workout_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/history_entities.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl(this._workouts);

  final WorkoutLocalDataSource _workouts;

  @override
  Stream<ApiResult<List<SessionRecord>>> watchCompletedSessions() =>
      guardStream(
        _workouts.watch(() {
          final index = _workouts.snapshot();
          return [
            for (final s in _workouts.sessions(status: SessionStatus.completed))
              _record(index, s.id),
          ];
        }),
      );

  @override
  Future<ApiResult<SessionRecord>> getSession(String sessionId) =>
      guardStorage(() => _record(_workouts.snapshot(), sessionId));

  SessionRecord _record(WorkoutIndex index, String sessionId) => SessionRecord(
    session:
        index.session(sessionId) ??
        (throw NotFoundException('Workout $sessionId not found.')),
    exercises: index.exercisesOf(sessionId),
    sets: index.setsOf(sessionId),
  );
}
