import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../domain/entities/history_entities.dart';
import '../../domain/usecases/history_use_cases.dart';

class HistoryCubit extends StreamViewCubit<HistoryData> {
  HistoryCubit({required this._watchHistory});

  final WatchHistoryUseCase _watchHistory;
  HistoryFilter _filter = const HistoryFilter();

  HistoryFilter get filter => _filter;

  @override
  Stream<ApiResult<HistoryData>> source() => _watchHistory(_filter);

  void applyFilter(HistoryFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    start();
  }
}

class SessionDetailCubit extends FutureViewCubit<SessionDetail> {
  SessionDetailCubit({required this.sessionId, required this._getDetail});

  final String sessionId;
  final GetSessionDetailUseCase _getDetail;

  @override
  Future<ApiResult<SessionDetail>> fetch() => _getDetail(sessionId);
}
