import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/result/api_result.dart';
import '../entities/settings_overview.dart';

abstract interface class SettingsRepository {
  Stream<ApiResult<SettingsOverview>> watchOverview();

  Future<VoidResult> saveSettings(AppSettings settings);

  Future<VoidResult> saveProfile(UserProfile profile);

  /// Workout days of the active program, for reminders.
  Future<ApiResult<List<({int weekday, String workoutName})>>> workoutDays();

  /// Wipes all local data and restores the seeded program.
  Future<VoidResult> deleteAllData();
}
