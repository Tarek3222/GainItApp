import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/training/performance_comparator.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/core/storage/hive_storage.dart';
import 'package:gainit/core/storage/local_data_sources/profile_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/program_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/settings_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/workout_local_data_source.dart';
import 'package:gainit/core/storage/seed/program_seed.dart';
import 'package:gainit/core/storage/storage_bootstrap.dart';
import 'package:gainit/features/history/data/repositories/history_repository_impl.dart';
import 'package:gainit/features/history/domain/entities/history_entities.dart';
import 'package:gainit/features/history/domain/usecases/history_use_cases.dart';
import 'package:gainit/features/startup/data/repositories/startup_repository_impl.dart';
import 'package:gainit/features/startup/domain/usecases/get_startup_status_use_case.dart';
import 'package:gainit/features/workout/data/repositories/workout_repository_impl.dart';
import 'package:gainit/features/workout/domain/entities/active_workout.dart';
import 'package:gainit/features/workout/domain/usecases/get_workout_summary_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/log_set_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/session_actions_use_cases.dart';
import 'package:gainit/features/workout/domain/usecases/start_workout_use_case.dart';
import 'package:gainit/features/workout/domain/usecases/watch_active_workout_use_case.dart';

import '../helpers/fixed_clock.dart';
import '../helpers/hive_test_harness.dart';

/// Wires the real data + domain layers over a temp Hive directory, the same
/// way `configureDependencies` does in the app.
class _App {
  _App(HiveStorage storage, this.clock) {
    final programs = ProgramLocalDataSource(storage);
    workouts = WorkoutLocalDataSource(storage, programs);
    final repo = WorkoutRepositoryImpl(
      workouts,
      SettingsLocalDataSource(storage),
      clock,
      const IdGenerator(),
    );
    start = StartWorkoutUseCase(repo);
    watch = WatchActiveWorkoutUseCase(repo);
    logSet = LogSetUseCase(repo, clock, const IdGenerator());
    finish = FinishWorkoutUseCase(repo);
    summary = GetWorkoutSummaryUseCase(repo);
    startup = GetStartupStatusUseCase(
      StartupRepositoryImpl(ProfileLocalDataSource(storage), workouts),
    );
    history = WatchHistoryUseCase(HistoryRepositoryImpl(workouts));
  }

  final FixedClock clock;
  late final WorkoutLocalDataSource workouts;
  late final StartWorkoutUseCase start;
  late final WatchActiveWorkoutUseCase watch;
  late final LogSetUseCase logSet;
  late final FinishWorkoutUseCase finish;
  late final GetWorkoutSummaryUseCase summary;
  late final GetStartupStatusUseCase startup;
  late final WatchHistoryUseCase history;

  Future<ActiveWorkout> current(String sessionId) async {
    final result = await watch(sessionId).first;
    return (result as ApiSuccess<ActiveWorkout>).data;
  }

  Future<void> logAll(String sessionId, List<(double, int)> perSet) async {
    for (final (weight, reps) in perSet) {
      final workout = await current(sessionId);
      final exercise = workout.exercises[workout.currentIndex!];
      final result = await logSet(
        LogSetInput(
          sessionExerciseId: exercise.snapshot.id,
          setNumber: exercise.nextSetNumber,
          weight: weight,
          reps: reps,
          plannedRepsMin: exercise.snapshot.repMin,
          plannedRepsMax: exercise.snapshot.repMax,
        ),
      );
      expect(result.isSuccess, isTrue);
      clock.advance(const Duration(minutes: 2));
    }
  }
}

void main() {
  final harness = HiveTestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test(
    'train → crash → resume → finish → summary → history → progression',
    () async {
      final clock = FixedClock(DateTime(2026, 3, 1, 18)); // Sunday
      await StorageBootstrap.run(harness.storage, now: clock.now());
      var app = _App(harness.storage, clock);

      // Week 1: first session of Sunday's workout, bench 30 kg 10/9/8.
      final first = await app.start(ProgramSeed.sundayId);
      final firstId = (first as ApiSuccess<String>).data;
      await app.logAll(firstId, [(30, 10), (30, 9), (30, 8)]);
      await app.finish(firstId);

      // Week 2: bench 30 kg 10/10/10, then the app is killed mid-workout.
      clock.current = DateTime(2026, 3, 8, 18);
      final secondId =
          ((await app.start(ProgramSeed.sundayId)) as ApiSuccess<String>).data;
      final beforeCrash = await app.current(secondId);
      final bench = beforeCrash.exercises.first;
      expect(bench.lastPerformance!.totalReps, 27);
      expect(bench.recommendation.type, RecommendationType.addReps);
      await app.logAll(secondId, [(30, 10), (30, 10), (30, 10), (40, 8)]);

      await harness.storage.close();
      final reopened = await HiveStorage.open();
      await StorageBootstrap.run(reopened, now: clock.now());
      app = _App(reopened, clock);

      // Relaunch: the interrupted workout is offered with its saved sets.
      final status =
          ((await app.startup()) as ApiSuccess).data.interruptedWorkout!;
      expect(status.sessionId, secondId);
      expect(status.completedSets, 4);
      expect(status.totalSets, 19);

      // Resume and finish.
      final resumed = await app.current(secondId);
      expect(resumed.exercises.first.completedSets, 3);
      expect(resumed.currentIndex, 1);
      await app.finish(secondId);

      final summary = (await app.summary(secondId) as ApiSuccess).data;
      final benchLine = summary.lines.firstWhere(
        (l) => l.exerciseId == 'ex_flat_barbell_bench',
      );
      expect(benchLine.comparison.outcome, ProgressOutcome.repsIncreased);
      expect(benchLine.comparison.repsDelta, 3);
      expect(summary.volume[MuscleGroup.chest], 3);

      // History lists both workouts, newest first; filters work.
      final history =
          ((await app.history(const HistoryFilter()).first) as ApiSuccess).data;
      expect(history.items.map((i) => i.sessionId), [secondId, firstId]);

      // Week 3: all sets hit the top of the range → add weight.
      clock.current = DateTime(2026, 3, 15, 18);
      final thirdId =
          ((await app.start(ProgramSeed.sundayId)) as ApiSuccess<String>).data;
      final third = await app.current(thirdId);
      expect(third.exercises.first.recommendation.suggestedWeight, 32.5);
    },
  );
}
