import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/services/step_counter.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../domain/entities/daily_goal_entities.dart';
import '../../domain/usecases/daily_goal_use_cases.dart';

/// The "Today's progress" card on Home.
class TodayGoalsCubit extends StreamViewCubit<TodayGoals> {
  TodayGoalsCubit({
    required this._watchToday,
    required this._logProgress,
    required this._stepAccess,
  });

  final WatchTodayGoalsUseCase _watchToday;
  final LogGoalProgressUseCase _logProgress;
  final StepAccessUseCase _stepAccess;

  @override
  Stream<ApiResult<TodayGoals>> source() => _watchToday();

  /// Adds [delta] (negative to undo) to today's progress; resolves to the
  /// amount really applied.
  Future<ActionOutcome<double>> addProgress(
    String goalId,
    double delta,
  ) async => ActionOutcome.from(await _logProgress(goalId, delta));

  /// Asks for step-sensor access and restarts watching, so the card shows
  /// the new state.
  Future<StepAccess> enableStepCounting() async {
    final access = await _stepAccess.request();
    if (!isClosed) start();
    return access;
  }

  Future<void> openStepSettings() => _stepAccess.openSettings();
}

/// The goal settings screen.
class DailyGoalsCubit extends StreamViewCubit<List<DailyGoal>> {
  DailyGoalsCubit({
    required this._watchGoals,
    required this._saveGoal,
    required this._removeGoal,
  });

  final WatchDailyGoalsUseCase _watchGoals;
  final SaveGoalUseCase _saveGoal;
  final RemoveGoalUseCase _removeGoal;

  @override
  Stream<ApiResult<List<DailyGoal>>> source() => _watchGoals();

  Future<ActionOutcome<void>> save(
    GoalInput input, {
    DailyGoal? existing,
  }) async => ActionOutcome.from(await _saveGoal(input, existing: existing));

  Future<ActionOutcome<void>> remove(DailyGoal goal) async =>
      ActionOutcome.from(await _removeGoal(goal));
}
