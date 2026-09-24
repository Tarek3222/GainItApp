import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/local_data_sources/profile_local_data_source.dart';
import '../../../../core/storage/local_data_sources/program_local_data_source.dart';
import '../../../../core/storage/local_data_sources/settings_local_data_source.dart';
import '../../../../core/storage/storage_bootstrap.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/settings_overview.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(
    this._storage,
    this._settings,
    this._profile,
    this._programs,
    this._clock,
  );

  final HiveStorage _storage;
  final SettingsLocalDataSource _settings;
  final ProfileLocalDataSource _profile;
  final ProgramLocalDataSource _programs;
  final Clock _clock;

  @override
  Stream<ApiResult<SettingsOverview>> watchOverview() => guardStream(
    watchTriggers(
      [..._settings.triggers, ..._profile.triggers],
      () => SettingsOverview(
        settings: _settings.settings(),
        profile: _profile.profile(),
      ),
    ),
  );

  @override
  Future<VoidResult> saveSettings(AppSettings settings) =>
      guardStorage(() => _settings.save(settings));

  @override
  Future<VoidResult> saveProfile(UserProfile profile) =>
      guardStorage(() => _profile.save(profile));

  @override
  Future<ApiResult<List<({int weekday, String workoutName})>>> workoutDays() =>
      guardStorage(() {
        final program = _programs.requireActiveProgram();
        return [
          for (final day in _programs.days(program.id))
            if (day.isWorkout) (weekday: day.weekday, workoutName: day.name),
        ];
      });

  @override
  Future<VoidResult> deleteAllData() => guardStorage(() async {
    await _storage.clearAll();
    await StorageBootstrap.run(_storage, now: _clock.now());
  });
}
