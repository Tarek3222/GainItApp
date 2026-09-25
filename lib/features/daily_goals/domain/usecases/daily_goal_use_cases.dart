import 'dart:async';

import '../../../../core/domain/entities/daily_goal.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/goals/goal_reminder_planner.dart';
import '../../../../core/domain/goals/step_day_tracker.dart';
import '../../../../core/domain/services/day_change_source.dart';
import '../../../../core/domain/services/notification_scheduler.dart';
import '../../../../core/domain/services/step_counter.dart';
import '../../../../core/domain/utils/dates.dart';
import '../../../../core/domain/utils/rebuild_on.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/id_generator.dart';
import '../entities/daily_goal_entities.dart';
import '../repositories/daily_goal_repository.dart';

/// Progress of every goal on the day of [now]. [sensorSteps] are added to
/// the step goal on top of the steps logged by hand.
List<GoalProgress> goalProgressOn(
  GoalData data,
  DateTime now, {
  int sensorSteps = 0,
}) {
  final today = dayKeyOf(now);
  final logged = <String, double>{
    for (final log in data.logs)
      if (log.dayKey == today) log.goalId: log.amount,
  };
  return [
    for (final goal in data.goals)
      if (goal.type == DailyGoalType.steps)
        GoalProgress(
          goal: goal,
          amount: (logged[goal.id] ?? 0) + sensorSteps,
          sensorAmount: sensorSteps.toDouble(),
        )
      else
        GoalProgress(goal: goal, amount: logged[goal.id] ?? 0),
  ];
}

/// Today's steps from the phone's sensor. Never fails: when the sensor
/// can't be used, the reading says why and the step goal falls back to
/// steps added by hand.
class WatchTodayStepsUseCase {
  const WatchTodayStepsUseCase(
    this._counter,
    this._repository,
    this._clock, {
    this.saveEvery = const Duration(minutes: 1),
  });

  final StepCounter _counter;
  final DailyGoalRepository _repository;
  final Clock _clock;

  /// How often the sensor state is saved while steps come in. The state
  /// is also saved on a new day, after a reboot and when watching stops.
  final Duration saveEvery;

  /// Emits the saved state first, then a reading per sensor event. Closes
  /// right away when the sensor can't be used.
  Stream<StepReading> call() {
    late final StreamController<StepReading> controller;
    StreamSubscription<int>? sensor;
    StepTrackerState? state;
    StepTrackerState? saved;
    DateTime? savedAt;
    var cancelled = false;

    void emit(StepStatus status) {
      if (controller.isClosed) return;
      controller.add(
        StepReading(
          status: status,
          dayKey: state?.dayKey,
          steps: state?.steps ?? 0,
        ),
      );
    }

    void finish(StepStatus status) {
      emit(status);
      unawaited(controller.close());
    }

    void save(StepTrackerState next, DateTime now) {
      saved = next;
      savedAt = now;
      unawaited(_repository.saveStepState(next));
    }

    void onCount(int count) {
      final now = _clock.now();
      final previous = state;
      final next = StepDayTracker.update(previous, count, now);
      state = next;
      final baselineMoved =
          previous == null ||
          previous.baseline != next.baseline ||
          previous.dayKey != next.dayKey;
      final last = savedAt;
      if (baselineMoved || last == null || now.difference(last) >= saveEvery) {
        save(next, now);
      }
      emit(StepStatus.active);
    }

    Future<void> start() async {
      state = switch (await _repository.stepState()) {
        ApiSuccess(:final data) => data,
        ApiFailure() => null,
      };
      saved = state;
      StepAccess access;
      try {
        access = await _counter.checkAccess();
      } on Object {
        access = StepAccess.unsupported;
      }
      if (cancelled) return;
      switch (access) {
        case StepAccess.denied:
          return finish(StepStatus.needsPermission);
        case StepAccess.permanentlyDenied:
          return finish(StepStatus.blocked);
        case StepAccess.unsupported:
          return finish(StepStatus.unavailable);
        case StepAccess.granted:
          emit(StepStatus.active);
      }
      sensor = _counter.stepsSinceBoot().listen(
        onCount,
        // No step sensor on this phone.
        onError: (Object _) {
          unawaited(sensor?.cancel());
          finish(StepStatus.unavailable);
        },
      );
    }

    controller = StreamController<StepReading>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        cancelled = true;
        await sensor?.cancel();
        final latest = state;
        if (latest != null && latest != saved) {
          await _repository.saveStepState(latest);
        }
      },
    );
    return controller.stream;
  }
}

/// The "Today's progress" card: every goal with today's progress,
/// refreshed at midnight and on resume. When a goal with reminders is
/// reached (or no longer is), its reminders are rescheduled so they stop
/// for the rest of the day.
class WatchTodayGoalsUseCase {
  const WatchTodayGoalsUseCase(
    this._repository,
    this._steps,
    this._clock,
    this._dayChanges,
    this._syncReminders,
  );

  final DailyGoalRepository _repository;
  final WatchTodayStepsUseCase _steps;
  final Clock _clock;
  final DayChangeSource _dayChanges;
  final SyncGoalRemindersUseCase _syncReminders;

  /// Shown for the step goal while no sensor reading is needed.
  static const _noSteps = StepReading(status: StepStatus.active);

  Stream<ApiResult<TodayGoals>> call() {
    final source = _withSteps(
      _repository.watchGoals(sinceDay: previousDayKey(dayKeyOf(_clock.now()))),
    );
    Set<String>? reached;
    return rebuildOn(source, _dayChanges.changes, (value) {
      final goals = build(value.data, value.steps);
      final nowReached = {
        for (final progress in goals.goals)
          if (progress.isComplete && progress.goal.reminderEnabled)
            progress.goal.id,
      };
      final previous = reached;
      if (previous != null &&
          (previous.length != nowReached.length ||
              !previous.containsAll(nowReached))) {
        // Pass what is known now: the saved step count lags behind the
        // sensor, so the sync must not recount it.
        unawaited(
          _syncReminders(
            completedToday: {
              for (final progress in goals.goals)
                if (progress.isComplete) progress.goal.id,
            },
          ),
        );
      }
      reached = nowReached;
      return goals;
    });
  }

  TodayGoals build(GoalData data, StepReading steps) {
    final now = _clock.now();
    final sensorSteps = steps.dayKey == dayKeyOf(now) ? steps.steps : 0;
    return TodayGoals(
      goals: goalProgressOn(data, now, sensorSteps: sensorSteps),
      stepStatus: steps.status,
    );
  }

  /// Pairs goal data with step readings. The step sensor is only watched
  /// while there is a step goal.
  Stream<ApiResult<({GoalData data, StepReading steps})>> _withSteps(
    Stream<ApiResult<GoalData>> goals,
  ) {
    late final StreamController<ApiResult<({GoalData data, StepReading steps})>>
    controller;
    StreamSubscription<ApiResult<GoalData>>? goalSub;
    StreamSubscription<StepReading>? stepSub;
    ApiResult<GoalData>? latest;
    StepReading? reading;

    bool hasStepGoal(GoalData data) =>
        data.goals.any((g) => g.type == DailyGoalType.steps);

    void emit() {
      final value = latest;
      if (value == null || controller.isClosed) return;
      switch (value) {
        case ApiFailure(:final failure):
          controller.add(ApiFailure(failure));
        case ApiSuccess(:final data):
          if (!hasStepGoal(data)) {
            controller.add(ApiSuccess((data: data, steps: _noSteps)));
          } else if (reading case final steps?) {
            controller.add(ApiSuccess((data: data, steps: steps)));
          }
      }
    }

    void onGoals(ApiResult<GoalData> value) {
      latest = value;
      if (value case ApiSuccess(:final data)) {
        final needed = hasStepGoal(data);
        if (needed && stepSub == null) {
          stepSub = _steps().listen((steps) {
            reading = steps;
            emit();
          });
        } else if (!needed && stepSub != null) {
          unawaited(stepSub!.cancel());
          stepSub = null;
          reading = null;
        }
      }
      emit();
    }

    controller = StreamController(
      onListen: () {
        goalSub = goals.listen(onGoals, onError: controller.addError);
      },
      onCancel: () async {
        await goalSub?.cancel();
        await stepSub?.cancel();
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }
}

/// Goals for the goal settings screen.
class WatchDailyGoalsUseCase {
  const WatchDailyGoalsUseCase(this._repository);

  final DailyGoalRepository _repository;

  Stream<ApiResult<List<DailyGoal>>> call() => _repository.watchGoalList();
}

/// Adds progress to a goal for today, or takes some back with a negative
/// [delta] (never below 0). Resolves to the amount really applied, which
/// is what an undo must reverse.
class LogGoalProgressUseCase {
  const LogGoalProgressUseCase(this._repository, this._clock);

  final DailyGoalRepository _repository;
  final Clock _clock;

  Future<ApiResult<double>> call(String goalId, double delta) async {
    if (!delta.isFinite || delta == 0) {
      return const ApiFailure(ValidationFailure(['Enter an amount.']));
    }
    if (delta.abs() > Validators.maxGoalProgress) {
      return const ApiFailure(
        ValidationFailure(['That is more than a day can hold.']),
      );
    }
    final now = _clock.now();
    final change = await _repository.addProgress(
      goalId,
      dayKeyOf(now),
      delta,
      now: now,
    );
    return change.map((c) => c.applied);
  }
}

/// Creates a goal or updates [existing], and keeps its reminders in sync.
class SaveGoalUseCase {
  const SaveGoalUseCase(
    this._repository,
    this._scheduler,
    this._syncReminders,
    this._clock,
    this._ids,
  );

  final DailyGoalRepository _repository;
  final NotificationScheduler _scheduler;
  final SyncGoalRemindersUseCase _syncReminders;
  final Clock _clock;
  final IdGenerator _ids;

  Future<VoidResult> call(GoalInput input, {DailyGoal? existing}) async {
    final List<DailyGoal> goals;
    switch (await _repository.goalList()) {
      case ApiFailure(:final failure):
        return ApiFailure(failure);
      case ApiSuccess(:final data):
        goals = data;
    }
    // Removed elsewhere (e.g. another screen): don't bring it back.
    if (existing != null && !goals.any((g) => g.id == existing.id)) {
      return const ApiFailure(NotFoundFailure('That goal no longer exists.'));
    }

    final goal = _build(input, existing, goals);
    final others = [
      for (final g in goals)
        if (g.id != goal.id) g,
    ];
    // All checks run before the permission prompt, so a save that is
    // going to fail never asks for anything.
    final errors = [
      ...Validators.dailyGoal(goal),
      if (goal.type != DailyGoalType.custom &&
          others.any((g) => g.type == goal.type))
        'You already have a ${goal.type == DailyGoalType.water ? 'water' : 'step'} goal.',
      if (existing == null && others.length >= Validators.maxDailyGoals)
        'You can track up to ${Validators.maxDailyGoals} daily goals.',
      if (goal.reminderEnabled) ...Validators.goalReminders([...others, goal]),
    ];
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));

    final hadReminders = existing?.reminderEnabled ?? false;
    if (goal.reminderEnabled && !hadReminders) {
      final bool granted;
      try {
        granted = await _scheduler.requestPermission();
      } on Object {
        return const ApiFailure(
          UnexpectedFailure('Could not turn on reminders.'),
        );
      }
      if (!granted) {
        return const ApiFailure(
          InvalidStateFailure(
            'Notifications are turned off for GainIt in system settings.',
          ),
        );
      }
    }

    final saved = await _repository.saveGoal(goal);
    if (saved is ApiFailure<void> || !(goal.reminderEnabled || hadReminders)) {
      return saved;
    }
    return switch (await _syncReminders()) {
      ApiSuccess() => voidSuccess,
      ApiFailure() => const ApiFailure(
        InvalidStateFailure('Goal saved, but its reminders could not be set.'),
      ),
    };
  }

  DailyGoal _build(GoalInput input, DailyGoal? existing, List<DailyGoal> all) {
    final custom = input.type == DailyGoalType.custom;
    final title = custom ? input.title.trim() : '';
    final unit = custom ? input.unit.trim() : '';
    if (existing != null) {
      return existing.copyWith(
        target: input.target,
        title: title,
        unit: unit,
        increment: input.increment,
        reminderEnabled: input.reminderEnabled,
        reminderIntervalMinutes: input.reminderIntervalMinutes,
        reminderStartMinutes: input.reminderStartMinutes,
        reminderEndMinutes: input.reminderEndMinutes,
      );
    }
    final lastOrder = all.fold(
      -1,
      (max, g) => g.sortOrder > max ? g.sortOrder : max,
    );
    return DailyGoal(
      id: _ids.next(),
      type: input.type,
      target: input.target,
      sortOrder: lastOrder + 1,
      createdAt: _clock.now(),
      title: title,
      unit: unit,
      increment: input.increment,
      reminderEnabled: input.reminderEnabled,
      reminderIntervalMinutes: input.reminderIntervalMinutes,
      reminderStartMinutes: input.reminderStartMinutes,
      reminderEndMinutes: input.reminderEndMinutes,
    );
  }
}

/// Removes a goal with its progress and its reminders.
class RemoveGoalUseCase {
  const RemoveGoalUseCase(this._repository, this._syncReminders);

  final DailyGoalRepository _repository;
  final SyncGoalRemindersUseCase _syncReminders;

  Future<VoidResult> call(DailyGoal goal) async {
    final removed = await _repository.removeGoal(goal.id);
    if (removed is ApiSuccess<void> && goal.reminderEnabled) {
      await _syncReminders();
    }
    return removed;
  }
}

/// Reschedules every goal reminder from the stored goals. Goals already
/// reached today resume tomorrow. Runs at startup and after goal changes;
/// does nothing when the plan is the one already scheduled.
///
/// Runs are queued, so overlapping calls never interleave their cancel and
/// schedule steps, and one failed run never blocks the next. Register one
/// shared instance.
class SyncGoalRemindersUseCase {
  SyncGoalRemindersUseCase(this._repository, this._scheduler, this._clock);

  final DailyGoalRepository _repository;
  final NotificationScheduler _scheduler;
  final Clock _clock;

  Future<VoidResult> _last = Future.value(voidSuccess);

  /// [completedToday] overrides the goals counted as reached, for callers
  /// that know more than storage (the live step count).
  Future<VoidResult> call({Set<String>? completedToday}) {
    final run = _last.then((_) => _guarded(completedToday));
    _last = run;
    return run;
  }

  Future<VoidResult> _guarded(Set<String>? completedToday) async {
    try {
      return await _sync(completedToday);
    } on Object {
      return const ApiFailure(
        UnexpectedFailure('Could not schedule reminders.'),
      );
    }
  }

  Future<VoidResult> _sync(Set<String>? completedToday) async {
    final now = _clock.now();
    final today = dayKeyOf(now);
    final GoalData goals;
    switch (await _repository.goalData(sinceDay: today)) {
      case ApiFailure(:final failure):
        return ApiFailure(failure);
      case ApiSuccess(:final data):
        goals = data;
    }
    final reached =
        completedToday ??
        {
          for (final progress in goalProgressOn(
            goals,
            now,
            sensorSteps: switch (await _repository.stepState()) {
              ApiSuccess(:final data) => StepDayTracker.stepsOn(data, now),
              ApiFailure() => 0,
            },
          ))
            if (progress.isComplete) progress.goal.id,
        };
    final reminders = GoalReminderPlanner.plan(
      goals.goals,
      completedToday: reached,
    );
    final plan = GoalReminderPlanner.planKey(reminders, dayKey: today);
    if (await _repository.reminderPlan() case ApiSuccess(
      data: final last,
    ) when last == plan) {
      return voidSuccess;
    }
    if (reminders.isEmpty) {
      await _scheduler.cancelGoalReminders();
    } else {
      await _scheduler.scheduleGoalReminders(reminders);
    }
    await _repository.saveReminderPlan(plan);
    return voidSuccess;
  }
}

/// Asks for step-sensor access, or opens the system settings when it was
/// refused for good.
class StepAccessUseCase {
  const StepAccessUseCase(this._counter);

  final StepCounter _counter;

  Future<StepAccess> request() async {
    try {
      return await _counter.requestAccess();
    } on Object {
      return StepAccess.unsupported;
    }
  }

  Future<void> openSettings() async {
    try {
      await _counter.openSettings();
    } on Object {
      // Nothing else to offer; the card keeps its button.
    }
  }
}
