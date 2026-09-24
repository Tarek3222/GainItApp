import '../../../../core/result/api_result.dart';
import '../entities/startup_status.dart';

abstract interface class StartupRepository {
  Future<ApiResult<StartupData>> getStartupData();
}
