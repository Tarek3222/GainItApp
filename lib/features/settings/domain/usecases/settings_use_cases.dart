import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/domain/services/notification_scheduler.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../entities/settings_overview.dart';
import '../repositories/settings_repository.dart';

class WatchSettingsUseCase {
  const WatchSettingsUseCase(this._repository, this._clock);

  final SettingsRepository _repository;
  final Clock _clock;

  Stream<ApiResult<SettingsOverview>> call() => _repository.watchOverview().map(
    (result) => result.map(
      (overview) => overview.withAge(overview.profile?.ageOn(_clock.now())),
    ),
  );
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

  /// [age] replaces the stored birth date when given.
  Future<VoidResult> call(UserProfile profile, {int? age}) async {
    final now = _clock.now();
    final updated = profile.copyWith(
      birthDate: age == null ? null : UserProfile.birthDateFor(age, now),
      updatedAt: now,
    );
    final errors = [
      ...Validators.profile(updated),
      if (age != null) ...Validators.age(age),
    ];
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    return _repository.saveProfile(updated);
  }
}

/// Lets the user pick a new profile photo, saves it, then removes the
/// previous file. Cancelling the picker changes nothing.
class UpdateProfilePhotoUseCase {
  const UpdateProfilePhotoUseCase(this._repository, this._media, this._clock);

  final SettingsRepository _repository;
  final MediaStore _media;
  final Clock _clock;

  Future<VoidResult> call(UserProfile profile, MediaSource source) async {
    final picked = await _media.pickImage(source);
    switch (picked) {
      case ApiFailure(:final failure):
        return ApiFailure(failure);
      case ApiSuccess(data: null):
        return voidSuccess;
      case ApiSuccess(:final data?):
        final saved = await _repository.saveProfile(
          profile.copyWith(photoPath: data, updatedAt: _clock.now()),
        );
        if (saved is ApiFailure<void>) {
          // Don't leave an orphaned copy behind.
          await _media.delete(data);
          return saved;
        }
        final previous = profile.photoPath;
        if (previous != null && previous != data) {
          await _media.delete(previous);
        }
        return voidSuccess;
    }
  }
}

class RemoveProfilePhotoUseCase {
  const RemoveProfilePhotoUseCase(this._repository, this._media, this._clock);

  final SettingsRepository _repository;
  final MediaStore _media;
  final Clock _clock;

  Future<VoidResult> call(UserProfile profile) async {
    final previous = profile.photoPath;
    if (previous == null) return voidSuccess;
    final saved = await _repository.saveProfile(
      profile.copyWith(clearPhoto: true, updatedAt: _clock.now()),
    );
    if (saved is ApiSuccess<void>) await _media.delete(previous);
    return saved;
  }
}

class DeleteAllDataUseCase {
  const DeleteAllDataUseCase(this._repository, this._scheduler, this._media);

  final SettingsRepository _repository;
  final NotificationScheduler _scheduler;
  final MediaStore _media;

  Future<VoidResult> call() async {
    final result = await _repository.deleteAllData();
    if (result is ApiSuccess<void>) {
      // Photos are personal data too. Best effort: the data is already gone,
      // so a leftover file must not block the rest of the reset.
      await _media.clearAll();
      try {
        await _scheduler.cancelWorkoutReminders();
        await _scheduler.cancelGoalReminders();
        await _scheduler.cancelRestOver();
      } on Object {
        // Data is gone either way; stale notifications are harmless.
      }
    }
    return result;
  }
}
