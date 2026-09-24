import '../../../../core/result/api_result.dart';
import '../entities/history_entities.dart';

abstract interface class HistoryRepository {
  /// Completed sessions, most recent first.
  Stream<ApiResult<List<SessionRecord>>> watchCompletedSessions();

  Future<ApiResult<SessionRecord>> getSession(String sessionId);
}
