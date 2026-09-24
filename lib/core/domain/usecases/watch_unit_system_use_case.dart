import '../../result/api_result.dart';
import '../entities/enums.dart';
import '../repositories/unit_preference_repository.dart';

class WatchUnitSystemUseCase {
  const WatchUnitSystemUseCase(this._repository);

  final UnitPreferenceRepository _repository;

  Stream<ApiResult<UnitSystem>> call() => _repository.watch();
}
