import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/domain/services/notification_scheduler.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../entities/settings_overview.dart';
import '../repositories/settings_repository.dart';

class WatchSettingsUseCase {
  const WatchSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Stream<ApiResult<SettingsOverview>> call() => _repository.watchOverview();
}

/// Saves preferences and keeps workout reminders in sync with them.
class UpdateSettingsUseCase {
  const UpdateSettingsUseCase(this._repository, this._scheduler);

  final SettingsRepository _repository;
  final NotificationScheduler _scheduler;

  Future<VoidResult> call({
    required AppSettings previous,
    required AppSettings next,
  }) async {
    final remindersChanged =
        previous.remindersEnabled != next.remindersEnabled ||
        previous.reminderMinutesOfDay != next.reminderMinutesOfDay;

    if (next.remindersEnabled && !previous.remindersEnabled) {
      final granted = await _scheduler.requestPermission();
      if (!granted) {
        return const ApiFailure(
          InvalidStateFailure(
            'Notifications are turned off for GainIt in system settings.',
          ),
        );
      }
    }

    final saved = await _repository.saveSettings(next);
    if (saved is ApiFailure<void> || !remindersChanged) return saved;
    return _syncReminders(next);
  }

  Future<VoidResult> _syncReminders(AppSettings settings) async {
    try {
      if (!settings.remindersEnabled) {
        await _scheduler.cancelWorkoutReminders();
        return voidSuccess;
      }
      final days = await _repository.workoutDays();
      switch (days) {
        case ApiFailure(:final failure):
          return ApiFailure(failure);
        case ApiSuccess(:final data):
          await _scheduler.scheduleWorkoutReminders(
            days: data,
            minutesOfDay: settings.reminderMinutesOfDay,
          );
          return voidSuccess;
      }
    } on Object {
      return const ApiFailure(
        UnexpectedFailure('Could not schedule reminders.'),
      );
    }
  }
}

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository, this._clock);

  final SettingsRepository _repository;
  final Clock _clock;

  Future<VoidResult> call(UserProfile profile) async {
    final updated = profile.copyWith(updatedAt: _clock.now());
    final errors = Validators.profile(updated);
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    return _repository.saveProfile(updated);
  }
}

class DeleteAllDataUseCase {
  const DeleteAllDataUseCase(this._repository, this._scheduler);

  final SettingsRepository _repository;
  final NotificationScheduler _scheduler;

  Future<VoidResult> call() async {
    final result = await _repository.deleteAllData();
    if (result is ApiSuccess<void>) {
      try {
        await _scheduler.cancelWorkoutReminders();
        await _scheduler.cancelRestOver();
      } on Object {
        // Data is gone either way; stale notifications are harmless.
      }
    }
    return result;
  }
}
