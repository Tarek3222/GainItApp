import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/goals/step_day_tracker.dart';
import '../../../../core/result/api_result.dart';
import '../entities/daily_goal_entities.dart';

abstract interface class DailyGoalRepository {
  /// Goals with their logs from the day [sinceDay] (`yyyymmdd`) on; emits
  /// again on every change.
  Stream<ApiResult<GoalData>> watchGoals({required int sinceDay});

  /// Current goals with their logs from the day [sinceDay] on.
  Future<ApiResult<GoalData>> goalData({required int sinceDay});

  /// Goals only, in display order; emits again when goals change.
  Stream<ApiResult<List<DailyGoal>>> watchGoalList();

  /// Goals only, in display order.
  Future<ApiResult<List<DailyGoal>>> goalList();

  Future<VoidResult> saveGoal(DailyGoal goal);

  /// Removes the goal with all its progress.
  Future<VoidResult> removeGoal(String id);

  /// Adds [delta] to the goal's progress on the day [dayKey].
  Future<ApiResult<ProgressChange>> addProgress(
    String goalId,
    int dayKey,
    double delta, {
    required DateTime now,
  });

  Future<ApiResult<StepTrackerState?>> stepState();

  Future<VoidResult> saveStepState(StepTrackerState state);

  /// The goal reminder plan last scheduled, if any.
  Future<ApiResult<String?>> reminderPlan();

  Future<VoidResult> saveReminderPlan(String plan);
}
