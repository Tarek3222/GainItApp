import '../../domain/entities/daily_goal.dart';
import '../../domain/entities/enums.dart';
import '../../domain/goals/step_day_tracker.dart';
import '../../domain/validation/validators.dart';
import '../../errors/exceptions.dart';
import '../hive_storage.dart';
import '../settings_keys.dart';
import '../storage_guard.dart';

class DailyGoalLocalDataSource {
  const DailyGoalLocalDataSource(this._storage);

  final HiveStorage _storage;

  static const waterGoalId = 'goal_water';
  static const stepsGoalId = 'goal_steps';

  /// One log per goal per day, so the ID is derived from both.
  static String logId(String goalId, int dayKey) => '${goalId}_$dayKey';

  /// In display order.
  List<DailyGoal> goals() => _storage.dailyGoals.values.toList()
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
    });

  /// Logs of every goal on the day [dayKey] or later.
  List<DailyGoalLog> logsSince(int dayKey) => _storage.dailyGoalLogs.values
      .where((log) => log.dayKey >= dayKey)
      .toList();

  Future<void> saveGoal(DailyGoal goal) async {
    ensureValid(Validators.dailyGoal(goal));
    final others = goals().where((g) => g.id != goal.id).toList();
    if (goal.type != DailyGoalType.custom &&
        others.any((g) => g.type == goal.type)) {
      throw ValidationException(['You already have a ${goal.type.name} goal.']);
    }
    if (!_storage.dailyGoals.containsKey(goal.id) &&
        others.length >= Validators.maxDailyGoals) {
      throw const ValidationException([
        'You can track up to ${Validators.maxDailyGoals} daily goals.',
      ]);
    }
    await _storage.dailyGoals.put(goal.id, goal);
  }

  /// Removes the goal and its logs (logs first, so an interruption never
  /// leaves logs without a goal).
  Future<void> deleteGoal(String id) async {
    final logIds = _storage.dailyGoalLogs.values
        .where((log) => log.goalId == id)
        .map((log) => log.id)
        .toList();
    await _storage.dailyGoalLogs.deleteAll(logIds);
    await _storage.dailyGoals.delete(id);
  }

  /// Adds [delta] (negative to take some back) to the goal's progress on
  /// the day [dayKey]. Progress never drops below 0.
  Future<ProgressChange> addProgress(
    String goalId,
    int dayKey,
    double delta,
    DateTime now,
  ) async {
    if (!_storage.dailyGoals.containsKey(goalId)) {
      throw const NotFoundException('That goal no longer exists.');
    }
    final id = logId(goalId, dayKey);
    final current = _storage.dailyGoalLogs.get(id)?.amount ?? 0;
    final total = current + delta;
    final log = DailyGoalLog(
      id: id,
      goalId: goalId,
      dayKey: dayKey,
      amount: total < 0 ? 0 : total,
      updatedAt: now,
    );
    ensureValid(Validators.dailyGoalLog(log));
    await _storage.dailyGoalLogs.put(id, log);
    return (total: log.amount, applied: log.amount - current);
  }

  /// Adds the default water and step goals on first run. Goals the user
  /// removes afterwards are not added again.
  Future<void> seedDefaultsOnce(DateTime now) async {
    if (_storage.settings.get(SettingsKeys.dailyGoalsSeeded) == true) return;
    if (_storage.dailyGoals.isEmpty) {
      await _storage.dailyGoals.putAll({
        waterGoalId: DailyGoal(
          id: waterGoalId,
          type: DailyGoalType.water,
          target: 3000,
          sortOrder: 0,
          createdAt: now,
          increment: 250,
        ),
        stepsGoalId: DailyGoal(
          id: stepsGoalId,
          type: DailyGoalType.steps,
          target: 10000,
          sortOrder: 1,
          createdAt: now,
          increment: 1000,
        ),
      });
    }
    await _storage.settings.put(SettingsKeys.dailyGoalsSeeded, true);
  }

  StepTrackerState? stepState() {
    final box = _storage.settings;
    final dayKey = box.get(SettingsKeys.stepTrackerDayKey);
    final baseline = box.get(SettingsKeys.stepTrackerBaseline);
    final lastCount = box.get(SettingsKeys.stepTrackerLastCount);
    if (dayKey is! int || baseline is! int || lastCount is! int) return null;
    return StepTrackerState(
      dayKey: dayKey,
      baseline: baseline,
      lastCount: lastCount,
    );
  }

  Future<void> saveStepState(StepTrackerState state) async {
    ensureValid(Validators.stepTracker(state));
    await _storage.settings.putAll({
      SettingsKeys.stepTrackerDayKey: state.dayKey,
      SettingsKeys.stepTrackerBaseline: state.baseline,
      SettingsKeys.stepTrackerLastCount: state.lastCount,
    });
  }

  /// The reminder plan last scheduled; `null` when none was saved.
  String? reminderPlan() {
    final value = _storage.settings.get(SettingsKeys.goalReminderPlan);
    return value is String ? value : null;
  }

  Future<void> saveReminderPlan(String plan) =>
      _storage.settings.put(SettingsKeys.goalReminderPlan, plan);

  /// Goals only, for screens that don't show progress.
  List<ChangeTrigger> get goalTriggers => [_storage.dailyGoals.watch];

  List<ChangeTrigger> get triggers => [
    _storage.dailyGoals.watch,
    _storage.dailyGoalLogs.watch,
  ];
}
