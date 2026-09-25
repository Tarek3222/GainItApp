import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/body_weight_entry.dart';
import '../domain/entities/daily_goal.dart';
import '../domain/entities/program.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/workout_session.dart';
import 'adapters/hive_adapters.dart';
import 'adapters/hive_registrar.g.dart';
import 'box_names.dart';

/// Owns every opened Hive box. Hive must be initialised (`Hive.initFlutter`
/// in the app, `Hive.init(tempDir)` in tests) before calling [open].
class HiveStorage {
  HiveStorage._({
    required this.profile,
    required this.programs,
    required this.workoutDays,
    required this.exercises,
    required this.programExercises,
    required this.sessions,
    required this.sessionExercises,
    required this.setLogs,
    required this.bodyWeights,
    required this.settings,
    required this.dailyGoals,
    required this.dailyGoalLogs,
  });

  final Box<UserProfile> profile;
  final Box<Program> programs;
  final Box<WorkoutDay> workoutDays;
  final Box<Exercise> exercises;
  final Box<ProgramExercise> programExercises;
  final Box<WorkoutSession> sessions;
  final Box<SessionExercise> sessionExercises;
  final Box<SetLog> setLogs;
  final Box<BodyWeightEntry> bodyWeights;
  final Box<Object?> settings;
  final Box<DailyGoal> dailyGoals;
  final Box<DailyGoalLog> dailyGoalLogs;

  /// [inMemory] opens every box without touching disk — for widget tests,
  /// where real file IO does not complete inside the fake-async zone.
  static Future<HiveStorage> open({
    HiveInterface? hive,
    bool inMemory = false,
  }) async {
    final h = hive ?? Hive;
    // The generated registrar throws on duplicates; storage may be reopened
    // in the same isolate (tests, relaunch simulation).
    if (!h.isAdapterRegistered(UserProfileAdapter().typeId)) {
      h.registerAdapters();
    }
    Future<Box<T>> box<T>(String name) =>
        h.openBox<T>(name, bytes: inMemory ? Uint8List(0) : null);
    return HiveStorage._(
      profile: await box<UserProfile>(BoxNames.userProfile),
      programs: await box<Program>(BoxNames.programs),
      workoutDays: await box<WorkoutDay>(BoxNames.workoutDays),
      exercises: await box<Exercise>(BoxNames.exercises),
      programExercises: await box<ProgramExercise>(BoxNames.programExercises),
      sessions: await box<WorkoutSession>(BoxNames.workoutSessions),
      sessionExercises: await box<SessionExercise>(BoxNames.sessionExercises),
      setLogs: await box<SetLog>(BoxNames.setLogs),
      bodyWeights: await box<BodyWeightEntry>(BoxNames.bodyWeightLogs),
      settings: await box<Object?>(BoxNames.settings),
      dailyGoals: await box<DailyGoal>(BoxNames.dailyGoals),
      dailyGoalLogs: await box<DailyGoalLog>(BoxNames.dailyGoalLogs),
    );
  }

  List<Box<Object?>> get _all => [
    profile,
    programs,
    workoutDays,
    exercises,
    programExercises,
    sessions,
    sessionExercises,
    setLogs,
    bodyWeights,
    settings,
    dailyGoals,
    dailyGoalLogs,
  ];

  /// Wipes all user data. Children are cleared before parents so an
  /// interruption never leaves orphans that reference missing parents.
  Future<void> clearAll() async {
    await setLogs.clear();
    await sessionExercises.clear();
    await sessions.clear();
    await bodyWeights.clear();
    await dailyGoalLogs.clear();
    await dailyGoals.clear();
    await programExercises.clear();
    await exercises.clear();
    await workoutDays.clear();
    await programs.clear();
    await profile.clear();
    await settings.clear();
  }

  Future<void> close() async {
    for (final box in _all) {
      if (box.isOpen) await box.close();
    }
  }
}

/// Change sources of a local data source (one per watched box).
typedef ChangeTrigger = Stream<Object?> Function();

/// Emits [query] on listen and again after any [triggers] fire, so a
/// repository can combine changes from several data sources.
Stream<T> watchTriggers<T>(List<ChangeTrigger> triggers, T Function() query) {
  final subscriptions = <StreamSubscription<Object?>>[];
  late final StreamController<T> controller;
  var pending = false;

  void emit() {
    if (controller.isClosed) return;
    try {
      controller.add(query());
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }

  void schedule() {
    if (pending) return;
    pending = true;
    scheduleMicrotask(() {
      pending = false;
      emit();
    });
  }

  controller = StreamController<T>(
    onListen: () {
      emit();
      for (final trigger in triggers) {
        subscriptions.add(trigger().listen((_) => schedule()));
      }
    },
    onCancel: () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      unawaited(controller.close());
    },
  );
  return controller.stream;
}
