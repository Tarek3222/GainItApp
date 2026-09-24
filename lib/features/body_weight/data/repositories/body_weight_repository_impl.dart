import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/local_data_sources/body_weight_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/repositories/body_weight_repository.dart';

class BodyWeightRepositoryImpl implements BodyWeightRepository {
  const BodyWeightRepositoryImpl(this._weights);

  final BodyWeightLocalDataSource _weights;

  @override
  Stream<ApiResult<List<BodyWeightEntry>>> watchEntries() =>
      guardStream(_weights.watch());

  @override
  Future<VoidResult> save(BodyWeightEntry entry) =>
      guardStorage(() => _weights.save(entry));

  @override
  Future<VoidResult> delete(String id) =>
      guardStorage(() => _weights.delete(id));
}
