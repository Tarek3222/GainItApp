import 'hive_storage.dart';
import 'local_data_sources/daily_goal_local_data_source.dart';
import 'local_data_sources/program_local_data_source.dart';
import 'local_data_sources/settings_local_data_source.dart';
import 'migrations/storage_migrator.dart';
import 'storage_integrity_check.dart';

/// Startup sequence for local storage: migrate → repair → seed.
abstract final class StorageBootstrap {
  static Future<void> run(HiveStorage storage, {required DateTime now}) async {
    final settings = SettingsLocalDataSource(storage);
    await StorageMigrator(storage, settings).run();
    await StorageIntegrityCheck(storage).run();
    await ProgramLocalDataSource(storage).seedIfEmpty(now);
    await DailyGoalLocalDataSource(storage).seedDefaultsOnce(now);
  }
}
