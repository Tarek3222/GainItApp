import '../../result/api_result.dart';
import '../entities/enums.dart';

/// The unit system the user chose for displaying weights and heights.
abstract interface class UnitPreferenceRepository {
  /// Emits the current choice, then every change. Metric until a profile
  /// exists.
  Stream<ApiResult<UnitSystem>> watch();
}
