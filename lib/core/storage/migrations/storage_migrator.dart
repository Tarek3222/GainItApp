import '../hive_storage.dart';
import '../local_data_sources/settings_local_data_source.dart';
import 'one_kg_weight_step_migration.dart';

/// One upgrade from `version - 1` to `version`. Steps must transform records
/// in place and never clear boxes — workout history must survive (spec §23).
typedef MigrationStep = Future<void> Function(HiveStorage storage);

/// Runs ordered storage migrations at startup.
///
/// Adding an optional field needs no step (adapters default missing fields).
/// Add a step only for real data transformations, e.g.:
/// `2: (s) async { /* backfill exercise notes */ }`.
class StorageMigrator {
  const StorageMigrator(
    this._storage,
    this._settings, {
    this.currentVersion = latestVersion,
    this.steps = defaultSteps,
  });

  static const latestVersion = 2;

  static const Map<int, MigrationStep> defaultSteps = {
    2: migrateToOneKgWeightStep,
  };

  final HiveStorage _storage;
  final SettingsLocalDataSource _settings;
  final int currentVersion;
  final Map<int, MigrationStep> steps;

  /// Returns the versions that were applied.
  Future<List<int>> run() async {
    var stored = _settings.schemaVersion();
    if (stored == null) {
      if (!_hasUserData) {
        // Fresh install: nothing to migrate.
        await _settings.setSchemaVersion(currentVersion);
        return const [];
      }
      // Data exists but the version stamp is missing (e.g. the settings box
      // was lost). Assume the oldest schema so no step is skipped.
      stored = 1;
    }
    final applied = <int>[];
    for (var version = stored + 1; version <= currentVersion; version++) {
      final step = steps[version];
      if (step != null) await step(_storage);
      // Persist after each step so an interrupted upgrade resumes correctly.
      await _settings.setSchemaVersion(version);
      applied.add(version);
    }
    if (_settings.schemaVersion() != currentVersion) {
      await _settings.setSchemaVersion(currentVersion);
    }
    return applied;
  }

  bool get _hasUserData =>
      _storage.programs.isNotEmpty ||
      _storage.sessions.isNotEmpty ||
      _storage.profile.isNotEmpty ||
      _storage.bodyWeights.isNotEmpty;
}
