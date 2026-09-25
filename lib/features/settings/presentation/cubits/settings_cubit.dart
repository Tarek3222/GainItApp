import 'package:easy_localization/easy_localization.dart';

import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../../daily_goals/domain/usecases/daily_goal_use_cases.dart';
import '../../domain/entities/settings_overview.dart';
import '../../domain/usecases/settings_use_cases.dart';

class SettingsCubit extends StreamViewCubit<SettingsOverview> {
  SettingsCubit({
    required this._watchSettings,
    required this._updateSettings,
    required this._updateProfile,
    required this._updatePhoto,
    required this._removePhoto,
    required this._deleteAllData,
    required this._syncGoalReminders,
  });

  final WatchSettingsUseCase _watchSettings;
  final UpdateSettingsUseCase _updateSettings;
  final UpdateProfileUseCase _updateProfile;
  final UpdateProfilePhotoUseCase _updatePhoto;
  final RemoveProfilePhotoUseCase _removePhoto;
  final DeleteAllDataUseCase _deleteAllData;
  final SyncGoalRemindersUseCase _syncGoalReminders;

  @override
  Stream<ApiResult<SettingsOverview>> source() => _watchSettings();

  Future<ActionOutcome<void>> updateSettings(
    AppSettings Function(AppSettings current) change,
  ) async {
    final current = state;
    if (current is! ViewLoaded<SettingsOverview>) {
      return ActionFailed('common.stillLoading'.tr());
    }
    final previous = current.data.settings;
    return ActionOutcome.from(
      await _updateSettings(previous: previous, next: change(previous)),
    );
  }

  /// Saves the app language ([code] `null` = phone language) and
  /// reschedules reminders so their texts are in it. Call it once the app
  /// shows the new language.
  Future<ActionOutcome<void>> changeLanguage(String? code) async {
    final saved = await updateSettings(
      (s) => s.copyWith(languageCode: code, useSystemLanguage: code == null),
    );
    if (saved is ActionFailed<void>) return saved;
    return switch (await _syncGoalReminders()) {
      ApiSuccess() => const ActionDone(null),
      ApiFailure() => ActionFailed('errors.remindersNotUpdated'.tr()),
    };
  }

  Future<ActionOutcome<void>> updateProfile(
    UserProfile profile, {
    int? age,
  }) async => ActionOutcome.from(await _updateProfile(profile, age: age));

  Future<ActionOutcome<void>> updatePhoto(
    UserProfile profile,
    MediaSource source,
  ) async => ActionOutcome.from(await _updatePhoto(profile, source));

  Future<ActionOutcome<void>> removePhoto(UserProfile profile) async =>
      ActionOutcome.from(await _removePhoto(profile));

  Future<ActionOutcome<void>> deleteAllData() async =>
      ActionOutcome.from(await _deleteAllData());
}
