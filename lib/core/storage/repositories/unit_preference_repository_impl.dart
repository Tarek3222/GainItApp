import '../../domain/entities/enums.dart';
import '../../domain/repositories/unit_preference_repository.dart';
import '../../result/api_result.dart';
import '../local_data_sources/profile_local_data_source.dart';
import '../storage_guard.dart';

class UnitPreferenceRepositoryImpl implements UnitPreferenceRepository {
  const UnitPreferenceRepositoryImpl(this._profile);

  final ProfileLocalDataSource _profile;

  @override
  Stream<ApiResult<UnitSystem>> watch() => guardStream(
    _profile.watch().map((p) => p?.unitSystem ?? UnitSystem.metric).distinct(),
  );
}
