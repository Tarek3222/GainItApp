import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/services/notification_scheduler.dart';
import '../../../../core/result/api_result.dart';
import '../repositories/workout_repository.dart';

class GetRestTimerSettingsUseCase {
  const GetRestTimerSettingsUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<ApiResult<AppSettings>> call() => _repository.getSettings();
}

/// Asks for notification permission so "rest over" alerts can appear while
/// the app is in the background. Called when a workout screen opens; if
/// permission is already granted it returns immediately.
class PrepareRestAlertsUseCase {
  const PrepareRestAlertsUseCase(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<bool> call() async {
    try {
      return await _scheduler.requestPermission();
    } on Object {
      return false;
    }
  }
}

/// Shows a background countdown and "rest over" alert. Failures are ignored
/// on purpose: a missing notification must never break the workout.
class ScheduleRestAlertUseCase {
  const ScheduleRestAlertUseCase(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> call({
    required DateTime endsAt,
    required String exerciseName,
  }) async {
    try {
      await _scheduler.scheduleRestOver(
        endsAt: endsAt,
        exerciseName: exerciseName,
      );
    } on Object {
      // Notifications are best-effort.
    }
  }
}

class CancelRestAlertUseCase {
  const CancelRestAlertUseCase(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> call() async {
    try {
      await _scheduler.cancelRestOver();
    } on Object {
      // Notifications are best-effort.
    }
  }
}
