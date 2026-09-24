import '../../../../core/result/api_result.dart';
import '../entities/home_dashboard.dart';

abstract interface class HomeRepository {
  Stream<ApiResult<HomeData>> watchHomeData();
}
