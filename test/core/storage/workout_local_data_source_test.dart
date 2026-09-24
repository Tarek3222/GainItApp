import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/errors/exceptions.dart';
import 'package:gainit/core/storage/local_data_sources/program_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/settings_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/workout_local_data_source.dart';
import 'package:gainit/core/storage/migrations/exercise_images_migration.dart';
import 'package:gainit/core/storage/migrations/storage_migrator.dart';
import 'package:gainit/core/storage/seed/program_seed.dart';
import 'package:gainit/core/storage/storage_integrity_check.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late WorkoutLocalDataSource workouts;
  var idCounter = 0;
  String newId() => 'id${idCounter++}';
  final now = DateTime(2026, 3, 1, 18);

  setUp(() async {
    idCounter = 0;
    await harness.setUp();
    final programs = ProgramLocalDataSource(harness.storage);
    await programs.seedIfEmpty(now);
    workouts = WorkoutLocalDataSource(harness.storage, programs);
  });
  tearDown(harness.tearDown);

  SetLog setFor(SessionExercise e, int n, {int reps = 8, double weight = 30}) =>
      SetLog(
        id: newId(),
        sessionExerciseId: e.id,
        setNumber: n,
        plannedRepsMin: e.repMin,
        plannedRepsMax: e.repMax,
        actualWeight: weight,
        actualReps: reps,
        completedAt: now,
      );

  Future<WorkoutSession> start() => workouts.startSession(
    dayId: ProgramSeed.sundayId,
    now: now,
    newId: newId,
  );

  group('startSession', () {
    test('snapshots every exercise of the day', () async {
      final session = await start();
      final exercises = workouts.exercisesOf(session.id);

      expect(session.status, SessionStatus.inProgress);
      expect(exercises, hasLength(7));
      expect(exercises.first.exerciseName, 'Flat Barbell Bench Press');
      expect(exercises.first.targetSets, 3);
    });

    test('starting the running day again returns the same session', () async {
      final first = await start();

      final again = await start();

      expect(again.id, first.id);
      expect(harness.storage.sessions.length, 1);
    });

    test('refuses to start another day while one is in progress', () async {
      await start();

      await expectLater(
        workouts.startSession(
          dayId: ProgramSeed.mondayId,
          now: now,
          newId: newId,
        ),
        throwsA(isA<InvalidStateException>()),
      );
    });

    test('concurrent starts create exactly one session', () async {
      final results = await Future.wait([start(), start(), start()]);

      expect(results.map((s) => s.id).toSet(), hasLength(1));
      expect(harness.storage.sessions.length, 1);
    });

    test('refuses to start a rest day', () {
      expect(
        () => workouts.startSession(
          dayId: 'day_sat_rest',
          now: now,
          newId: newId,
        ),
        throwsA(isA<InvalidStateException>()),
      );
    });
  });

  group('saveSet', () {
    test('persists each set immediately', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;

      await workouts.saveSet(setFor(bench, 1));

      expect(workouts.setsOf(session.id), hasLength(1));
    });

    test('rejects invalid values before writing', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;

      await expectLater(
        workouts.saveSet(setFor(bench, 1, reps: -1)),
        throwsA(isA<ValidationException>()),
      );
      expect(harness.storage.setLogs.isEmpty, isTrue);
    });

    test('rejects a 0-rep working set', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;

      await expectLater(
        workouts.saveSet(setFor(bench, 1, reps: 0)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects sets on a finished workout', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;
      await workouts.finish(
        session.id,
        status: SessionStatus.completed,
        at: now,
      );

      await expectLater(
        workouts.saveSet(setFor(bench, 1)),
        throwsA(isA<InvalidStateException>()),
      );
    });
  });

  group('deleteSet (undo)', () {
    test('removes the latest set', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;
      final first = setFor(bench, 1);
      final second = setFor(bench, 2);
      await workouts.saveSet(first);
      await workouts.saveSet(second);

      await workouts.deleteSet(second.id);

      expect(workouts.setsOf(session.id).map((s) => s.setNumber), [1]);
    });

    test('refuses to remove an earlier set', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;
      final first = setFor(bench, 1);
      await workouts.saveSet(first);
      await workouts.saveSet(setFor(bench, 2));

      await expectLater(
        workouts.deleteSet(first.id),
        throwsA(isA<InvalidStateException>()),
      );
      expect(workouts.setsOf(session.id), hasLength(2));
    });
  });

  group('finish', () {
    test('dates a forgotten workout at its last logged set', () async {
      final session = await start();
      final bench = workouts.exercisesOf(session.id).first;
      await workouts.saveSet(
        SetLog(
          id: newId(),
          sessionExerciseId: bench.id,
          setNumber: 1,
          plannedRepsMin: 6,
          plannedRepsMax: 10,
          actualWeight: 30,
          actualReps: 8,
          completedAt: now.add(const Duration(minutes: 20)),
        ),
      );

      final finished = await workouts.finish(
        session.id,
        status: SessionStatus.completed,
        at: now.add(const Duration(days: 7)),
      );

      expect(finished.completedAt, now.add(const Duration(minutes: 20)));
    });

    test(
      'never finishes before the start, even if the clock went back',
      () async {
        final session = await start();

        final abandoned = await workouts.finish(
          session.id,
          status: SessionStatus.abandoned,
          at: now.subtract(const Duration(hours: 1)),
        );

        expect(abandoned.completedAt, session.startedAt);
        expect(abandoned.status, SessionStatus.abandoned);
      },
    );
  });

  test('snapshot indexes every session consistently', () async {
    // 30 completed Sunday workouts × 7 exercises × 3 sets.
    for (var week = 0; week < 30; week++) {
      final at = now.add(Duration(days: 7 * week));
      final session = await workouts.startSession(
        dayId: ProgramSeed.sundayId,
        now: at,
        newId: newId,
      );
      for (final e in workouts.exercisesOf(session.id)) {
        for (var n = 1; n <= 3; n++) {
          await workouts.saveSet(setFor(e, n, reps: 6 + week % 5));
        }
      }
      await workouts.finish(
        session.id,
        status: SessionStatus.completed,
        at: at,
      );
    }

    final index = workouts.snapshot();
    final latest = workouts.sessions().first;

    expect(index.setsOf(latest.id), hasLength(21));
    expect(index.setsOf(latest.id), workouts.setsOf(latest.id));
    expect(
      index.performances('ex_flat_barbell_bench', limit: 5),
      workouts.performances('ex_flat_barbell_bench', limit: 5),
    );
    expect(index.performances('ex_flat_barbell_bench'), hasLength(30));
  });

  test('performances returns completed sessions only, newest first', () async {
    final first = await start();
    final bench1 = workouts.exercisesOf(first.id).first;
    await workouts.saveSet(setFor(bench1, 1, reps: 10));
    await workouts.finish(first.id, status: SessionStatus.completed, at: now);

    final second = await workouts.startSession(
      dayId: ProgramSeed.sundayId,
      now: now.add(const Duration(days: 7)),
      newId: newId,
    );
    final bench2 = workouts.exercisesOf(second.id).first;
    await workouts.saveSet(setFor(bench2, 1, reps: 11));

    // Second session still in progress → excluded.
    expect(workouts.performances(bench1.exerciseId), hasLength(1));

    await workouts.finish(
      second.id,
      status: SessionStatus.completed,
      at: now.add(const Duration(days: 7)),
    );
    final history = workouts.performances(bench1.exerciseId);

    expect(history.map((h) => h.sets.first.reps), [11, 10]);
  });

  test('watch emits again after a set is saved', () async {
    final session = await start();
    final bench = workouts.exercisesOf(session.id).first;
    final counts = workouts.watch(() => workouts.setsOf(session.id).length);

    final expectation = expectLater(counts, emitsInOrder([0, 1]));
    await workouts.saveSet(setFor(bench, 1));

    await expectation;
  });

  test('integrity check removes orphans from an interrupted write', () async {
    final session = await start();
    // Simulate a crash after children were written but before the parent.
    await harness.storage.sessions.delete(session.id);

    final removed = await StorageIntegrityCheck(harness.storage).run();

    expect(removed, 7);
    expect(harness.storage.sessionExercises.isEmpty, isTrue);
  });

  test('integrity check removes sets whose exercise is missing', () async {
    final session = await start();
    final bench = workouts.exercisesOf(session.id).first;
    await workouts.saveSet(setFor(bench, 1));
    await harness.storage.sessionExercises.delete(bench.id);

    final removed = await StorageIntegrityCheck(harness.storage).run();

    expect(removed, 1);
    expect(harness.storage.setLogs.isEmpty, isTrue);
  });

  test('integrity check keeps only the newest in-progress workout', () async {
    final older = Fixtures.session(id: 'old', startedAt: now);
    final newer = Fixtures.session(
      id: 'new',
      startedAt: now.add(const Duration(hours: 1)),
    );
    await harness.storage.sessions.putAll({older.id: older, newer.id: newer});

    await StorageIntegrityCheck(harness.storage).run();

    expect(harness.storage.sessions.get('new')!.isInProgress, isTrue);
    expect(
      harness.storage.sessions.get('old')!.status,
      SessionStatus.abandoned,
    );
  });

  group('StorageMigrator', () {
    test('stamps the latest version on a fresh install', () async {
      await harness.storage.clearAll();
      final settings = SettingsLocalDataSource(harness.storage);

      final applied = await StorageMigrator(
        harness.storage,
        settings,
        currentVersion: 3,
        steps: {2: (_) async => fail('fresh install must not migrate')},
      ).run();

      expect(applied, isEmpty);
      expect(settings.schemaVersion(), 3);
    });

    test('treats data without a version stamp as version 1', () async {
      // setUp seeded data but no version stamp exists.
      final settings = SettingsLocalDataSource(harness.storage);
      final ran = <int>[];

      final applied = await StorageMigrator(
        harness.storage,
        settings,
        currentVersion: 2,
        steps: {2: (_) async => ran.add(2)},
      ).run();

      expect(applied, [2]);
      expect(ran, [2]);
      expect(settings.schemaVersion(), 2);
    });

    test('runs pending steps in order and keeps data', () async {
      final settings = SettingsLocalDataSource(harness.storage);
      await settings.setSchemaVersion(1);
      await start();
      final ran = <int>[];

      final applied = await StorageMigrator(
        harness.storage,
        settings,
        currentVersion: 3,
        steps: {2: (_) async => ran.add(2), 3: (_) async => ran.add(3)},
      ).run();

      expect(applied, [2, 3]);
      expect(ran, [2, 3]);
      expect(settings.schemaVersion(), 3);
      expect(harness.storage.sessions.length, 1);
    });

    test('v3 moves the single exercise photo into the photo list', () async {
      final settings = SettingsLocalDataSource(harness.storage);
      await settings.setSchemaVersion(2);
      final squat = harness.storage.exercises.get('ex_squat')!;
      await harness.storage.exercises.put(
        squat.id,
        Exercise(
          id: squat.id,
          name: squat.name,
          primaryMuscle: squat.primaryMuscle,
          category: squat.category,
          createdAt: squat.createdAt,
          imagePath: 'legacy.jpg',
        ),
      );

      final applied = await StorageMigrator(harness.storage, settings).run();

      expect(applied, [3]);
      final migrated = harness.storage.exercises.get('ex_squat')!;
      expect(migrated.imagePaths, ['legacy.jpg']);
      expect(migrated.imagePath, isNull);

      // Running the step again changes nothing.
      await migrateExerciseImagesToList(harness.storage);
      expect(harness.storage.exercises.get('ex_squat'), migrated);
    });

    test('v3 does not duplicate a photo already in the list', () async {
      final squat = harness.storage.exercises.get('ex_squat')!;
      await harness.storage.exercises.put(
        squat.id,
        Exercise(
          id: squat.id,
          name: squat.name,
          primaryMuscle: squat.primaryMuscle,
          category: squat.category,
          createdAt: squat.createdAt,
          imagePath: 'a.jpg',
          imagePaths: const ['a.jpg', 'b.jpg'],
        ),
      );

      await migrateExerciseImagesToList(harness.storage);

      expect(harness.storage.exercises.get('ex_squat')!.imagePaths, [
        'a.jpg',
        'b.jpg',
      ]);
    });

    test('v2 moves program and active-session weight steps to 1 kg', () async {
      final settings = SettingsLocalDataSource(harness.storage);
      await settings.setSchemaVersion(1);
      final legacy = {
        for (final e in harness.storage.programExercises.values)
          e.id: e.copyWith(weightStep: 2.5),
      };
      await harness.storage.programExercises.putAll(legacy);
      final sessionId = (await start()).id;
      final active = harness.storage.sessionExercises.values.first;
      await harness.storage.sessionExercises.put(
        active.id,
        active.copyWith(weightStep: 2.5),
      );
      final finished = Fixtures.session(
        id: 'done',
        status: SessionStatus.completed,
        completedAt: DateTime(2026, 3, 2, 19),
      );
      final finishedExercise = Fixtures.sessionExercise(
        id: 'done-se',
        sessionId: finished.id,
      );
      await harness.storage.sessionExercises.put(
        finishedExercise.id,
        finishedExercise,
      );
      await harness.storage.sessions.put(finished.id, finished);

      final applied = await StorageMigrator(harness.storage, settings).run();

      expect(applied, [2, 3]);
      expect(
        harness.storage.programExercises.values.map((e) => e.weightStep),
        everyElement(1.0),
      );
      expect(
        harness.storage.sessionExercises.values
            .where((e) => e.sessionId == sessionId)
            .map((e) => e.weightStep),
        everyElement(1.0),
      );
      // Finished workouts keep their original snapshot.
      expect(harness.storage.sessionExercises.get('done-se')!.weightStep, 2.5);
    });
  });
}
