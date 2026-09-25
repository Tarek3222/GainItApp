import '../entities/app_settings.dart';
import '../entities/body_weight_entry.dart';
import '../entities/daily_goal.dart';
import '../entities/enums.dart';
import '../entities/program.dart';
import '../entities/user_profile.dart';
import '../entities/workout_session.dart';
import '../goals/step_day_tracker.dart';
import '../services/notification_scheduler.dart';

/// Data-integrity rules (spec §22). Hive has no CHECK constraints, so every
/// write goes through these before touching storage. Each returns a list of
/// error message keys (translated in presentation, with [messageArgs]);
/// empty means valid.
abstract final class Validators {
  /// Values for the `{placeholders}` in the error messages.
  static Map<String, String> get messageArgs => {
    'maxReps': '$maxReps',
    'maxWeightKg': _whole(maxWeightKg),
    'maxRir': '$maxRir',
    'maxWeightStepKg': _whole(maxWeightStepKg),
    'maxSets': '$maxSets',
    'maxRestMinutes': '${maxRestSeconds ~/ 60}',
    'maxSupersetGroup': '$maxSupersetGroup',
    'maxNotes': '$maxNotes',
    'minAge': '$minAge',
    'maxAge': '$maxAge',
    'maxExerciseName': '$maxExerciseName',
    'maxExerciseImages': '$maxExerciseImages',
    'maxDayName': '$maxDayName',
    'maxGoalTitle': '$maxGoalTitle',
    'maxGoalUnit': '$maxGoalUnit',
    'maxDailyGoals': '$maxDailyGoals',
    'maxGoalReminders': '${NotificationScheduler.maxGoalReminders}',
  };

  static String _whole(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  static const maxWeightKg = 1000.0;
  static const maxSets = 20;
  static const maxRestSeconds = 10 * 60;
  static const maxWeightStepKg = 10.0;
  static const maxSupersetGroup = 4;

  /// Lightest weight the set editor offers. Any weight above 0 is valid;
  /// this only sets the −/+ floor so small plates stay reachable.
  static const minSetWeightKg = 0.5;
  static const maxReps = 200;
  static const maxRir = 10;

  static List<String> setLog(SetLog set) => [
    if (set.setNumber < 1) 'validation.setNumberMin',
    if (set.actualReps < 1) 'validation.setRepsMin',
    if (set.actualReps > maxReps) 'validation.repsMax',
    if (set.actualWeight <= 0) 'validation.weightAboveZero',
    if (set.actualWeight > maxWeightKg) 'validation.weightMax',
    if (set.actualWeight.isNaN) 'validation.weightNumber',
    if (set.rir != null && set.rir! < 0) 'validation.rirNegative',
    if (set.rir != null && set.rir! > maxRir) 'validation.rirMax',
    if (set.plannedRepsMin < 1) 'validation.plannedRepsMin',
    if (set.plannedRepsMax < set.plannedRepsMin) 'validation.plannedRepsOrder',
  ];

  static List<String> programExercise(ProgramExercise e) => [
    if (e.workingSets < 1) 'validation.workingSetsMin',
    if (e.repMin < 1) 'validation.repsMin',
    if (e.repMax < e.repMin) 'validation.repsOrder',
    if (e.restMinSeconds < 0) 'validation.restNegative',
    if (e.restMaxSeconds < e.restMinSeconds) 'validation.restOrder',
    if (e.rirMin < 0) 'validation.rirNegative',
    if (e.rirMax < e.rirMin) 'validation.rirOrder',
    if (!e.weightStep.isFinite || e.weightStep <= 0)
      'validation.weightStepPositive',
    if (e.weightStep > maxWeightStepKg) 'validation.weightStepMax',
    if (e.workingSets > maxSets) 'validation.workingSetsMax',
    if (e.repMax > maxReps) 'validation.repsMax',
    if (e.restMaxSeconds > maxRestSeconds) 'validation.restMax',
    if (e.supersetGroup != null &&
        (e.supersetGroup! < 1 || e.supersetGroup! > maxSupersetGroup))
      'validation.supersetRange',
    if (e.rirMax > maxRir) 'validation.rirMax',
    if ((e.notes?.length ?? 0) > maxNotes) 'validation.notesMax',
  ];

  static List<String> sessionExercise(SessionExercise e) => [
    if (e.targetSets < 1) 'validation.targetSetsMin',
    if (e.repMin < 1) 'validation.repsMin',
    if (e.repMax < e.repMin) 'validation.repsOrder',
    if (e.restSeconds < 0) 'validation.restNegative',
  ];

  static List<String> bodyWeight(BodyWeightEntry e) => [
    if (e.weightKg.isNaN || e.weightKg < 20 || e.weightKg > 400)
      'validation.bodyWeightRange',
  ];

  static List<String> profile(UserProfile p) => [
    if (p.name.trim().isEmpty) 'validation.nameRequired',
    if (p.name.trim().length > 40) 'validation.nameMax',
    if (p.heightCm.isNaN || p.heightCm < 100 || p.heightCm > 250)
      'validation.heightRange',
  ];

  static const minAge = 13;
  static const maxAge = 90;

  static List<String> age(int age) => [
    if (age < minAge || age > maxAge) 'validation.ageRange',
  ];

  static const maxExerciseName = 60;
  static const maxExerciseImages = 10;
  static const maxNotes = 2000;
  static const maxDayName = 40;

  static List<String> exercise(Exercise e) => [
    if (e.name.trim().isEmpty) 'validation.exerciseNameRequired',
    if (e.name.trim().length > maxExerciseName) 'validation.exerciseNameMax',
    if (e.secondaryMuscles.contains(e.primaryMuscle))
      'validation.secondaryIsPrimary',
    if ((e.instructions?.length ?? 0) > maxNotes) 'validation.instructionsMax',
    if (e.photos.length > maxExerciseImages) 'validation.photosMax',
  ];

  static List<String> workoutDay(WorkoutDay d) => [
    if (d.name.trim().isEmpty) 'validation.dayNameRequired',
    if (d.name.trim().length > maxDayName) 'validation.dayNameMax',
  ];

  static List<String> program(Program p) => [
    if (p.name.trim().isEmpty) 'validation.programNameRequired',
  ];

  static List<String> settings(AppSettings s) => [
    if (s.reminderMinutesOfDay < 0 || s.reminderMinutesOfDay >= 24 * 60)
      'validation.reminderTimeRange',
    if (s.languageCode case final code?
        when !AppSettings.supportedLanguageCodes.contains(code))
      'validation.languageUnavailable',
  ];

  static const maxDailyGoals = 8;
  static const maxGoalTitle = 30;
  static const maxGoalUnit = 12;
  static const maxWaterTargetMl = 10000.0;
  static const maxStepTarget = 100000.0;
  static const maxCustomTarget = 100000.0;
  static const minReminderIntervalMinutes = 30;
  static const maxReminderIntervalMinutes = 12 * 60;

  /// Highest progress a single day can record on any goal.
  static const maxGoalProgress = 1000000.0;

  static List<String> dailyGoal(DailyGoal g) {
    final (maxTarget, tooHigh) = switch (g.type) {
      DailyGoalType.water => (maxWaterTargetMl, 'validation.waterTargetMax'),
      DailyGoalType.steps => (maxStepTarget, 'validation.stepTargetMax'),
      DailyGoalType.custom => (maxCustomTarget, 'validation.customTargetMax'),
    };
    return [
      if (!g.target.isFinite || g.target <= 0) 'validation.goalTargetPositive',
      if (g.target > maxTarget) tooHigh,
      if (g.type == DailyGoalType.custom && g.title.trim().isEmpty)
        'validation.goalNameRequired',
      if (g.title.trim().length > maxGoalTitle) 'validation.goalNameMax',
      if (g.unit.trim().length > maxGoalUnit) 'validation.goalUnitMax',
      // Only custom goals use their quick-add amount; water and steps use
      // fixed servings, so their stored amount must not block a target.
      if (g.type == DailyGoalType.custom &&
          (!g.increment.isFinite || g.increment <= 0))
        'validation.quickAddPositive',
      if (g.type == DailyGoalType.custom &&
          g.increment.isFinite &&
          g.increment > g.target)
        'validation.quickAddMax',
      if (g.reminderIntervalMinutes < minReminderIntervalMinutes ||
          g.reminderIntervalMinutes > maxReminderIntervalMinutes)
        'validation.reminderInterval',
      if (!_isTimeOfDay(g.reminderStartMinutes) ||
          !_isTimeOfDay(g.reminderEndMinutes))
        'validation.reminderTimesRange',
      if (g.reminderEndMinutes < g.reminderStartMinutes)
        'validation.reminderOrder',
    ];
  }

  static List<String> dailyGoalLog(DailyGoalLog l) => [
    if (!l.amount.isFinite || l.amount < 0) 'validation.progressNegative',
    if (l.amount.isFinite && l.amount > maxGoalProgress)
      'validation.progressMax',
  ];

  /// All goals together must fit the platform's pending-notification
  /// limit, or later goals would silently get no reminders.
  static List<String> goalReminders(List<DailyGoal> goals) {
    final total = goals.fold(0, (sum, g) => sum + g.reminderTimes.length);
    return [
      if (total > NotificationScheduler.maxGoalReminders)
        'validation.goalRemindersTotal',
    ];
  }

  static List<String> stepTracker(StepTrackerState s) => [
    if (s.lastCount < 0) 'validation.stepCountNegative',
    if (s.dayKey < 19000101 || s.dayKey > 99991231) 'validation.stepDayInvalid',
  ];

  static bool _isTimeOfDay(int minutes) => minutes >= 0 && minutes < 24 * 60;

  static List<String> session(WorkoutSession s) => [
    if (s.completedAt != null && s.completedAt!.isBefore(s.startedAt))
      'validation.workoutEndsBeforeStart',
  ];
}
