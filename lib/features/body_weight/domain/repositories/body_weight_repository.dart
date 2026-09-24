import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/result/api_result.dart';

abstract interface class BodyWeightRepository {
  /// Most recent first.
  Stream<ApiResult<List<BodyWeightEntry>>> watchEntries();

  Future<VoidResult> save(BodyWeightEntry entry);

  Future<VoidResult> delete(String id);
}
