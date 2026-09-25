import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/goals/step_day_tracker.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/local_data_sources/daily_goal_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/daily_goal_entities.dart';
import '../../domain/repositories/daily_goal_repository.dart';

class DailyGoalRepositoryImpl implements DailyGoalRepository {
  const DailyGoalRepositoryImpl(this._goals);

  final DailyGoalLocalDataSource _goals;

  GoalData _load(int sinceDay) =>
      GoalData(goals: _goals.goals(), logs: _goals.logsSince(sinceDay));

  @override
  Stream<ApiResult<GoalData>> watchGoals({required int sinceDay}) =>
      guardStream(watchTriggers(_goals.triggers, () => _load(sinceDay)));

  @override
  Future<ApiResult<GoalData>> goalData({required int sinceDay}) =>
      guardStorage(() => _load(sinceDay));

  @override
  Stream<ApiResult<List<DailyGoal>>> watchGoalList() =>
      guardStream(watchTriggers(_goals.goalTriggers, _goals.goals));

  @override
  Future<ApiResult<List<DailyGoal>>> goalList() => guardStorage(_goals.goals);

  @override
  Future<VoidResult> saveGoal(DailyGoal goal) =>
      guardStorage(() => _goals.saveGoal(goal));

  @override
  Future<VoidResult> removeGoal(String id) =>
      guardStorage(() => _goals.deleteGoal(id));

  @override
  Future<ApiResult<ProgressChange>> addProgress(
    String goalId,
    int dayKey,
    double delta, {
    required DateTime now,
  }) => guardStorage(() => _goals.addProgress(goalId, dayKey, delta, now));

  @override
  Future<ApiResult<StepTrackerState?>> stepState() =>
      guardStorage(_goals.stepState);

  @override
  Future<VoidResult> saveStepState(StepTrackerState state) =>
      guardStorage(() => _goals.saveStepState(state));

  @override
  Future<ApiResult<String?>> reminderPlan() =>
      guardStorage(_goals.reminderPlan);

  @override
  Future<VoidResult> saveReminderPlan(String plan) =>
      guardStorage(() => _goals.saveReminderPlan(plan));
}
