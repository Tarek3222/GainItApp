import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/errors/exceptions.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/storage/local_data_sources/body_weight_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/program_local_data_source.dart';
import 'package:gainit/core/storage/local_data_sources/workout_local_data_source.dart';
import 'package:gainit/core/storage/seed/program_seed.dart';
import 'package:gainit/features/exercises/data/repositories/exercise_repository_impl.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_details.dart';
import 'package:gainit/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:gainit/features/progress/domain/entities/progress_entities.dart';

import '../../helpers/fake_media_store.dart';
import '../../helpers/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late ProgramLocalDataSource programs;
  final now = DateTime(2026, 3, 1, 18);

  setUp(() async {
    await harness.setUp();
    programs = ProgramLocalDataSource(harness.storage);
    await programs.seedIfEmpty(now);
  });
  tearDown(harness.tearDown);

  List<String> dayOrder(String dayId) => [
    for (final p in programs.programExercisesForDay(dayId)) p.exerciseId,
  ];

  List<int> indexes(String dayId) => [
    for (final p in programs.programExercisesForDay(dayId)) p.orderIndex,
  ];

  test('an exercise with an empty name is rejected', () async {
    final squat = programs.requireExercise('ex_squat');

    expect(
      () => programs.saveExercise(squat.copyWith(name: '  ')),
      throwsA(isA<ValidationException>()),
    );
  });

  test('renaming a day and switching it to rest is saved', () async {
    final monday = programs.requireDay(ProgramSeed.mondayId);

    await programs.saveWorkoutDay(
      monday.copyWith(name: 'Lower body', type: DayType.rest),
    );

    final saved = programs.requireDay(ProgramSeed.mondayId);
    expect(saved.name, 'Lower body');
    expect(saved.isWorkout, isFalse);
  });

  test('removing an exercise keeps the order indexes contiguous', () async {
    final entries = programs.programExercisesForDay(ProgramSeed.mondayId);

    await programs.removeProgramExercise(entries[1].id);

    expect(programs.programExercisesForDay(ProgramSeed.mondayId), hasLength(5));
    expect(indexes(ProgramSeed.mondayId), [0, 1, 2, 3, 4]);
  });

  test('reordering applies the new order', () async {
    final ids = [
      for (final p in programs.programExercisesForDay(ProgramSeed.mondayId))
        p.id,
    ];
    final before = dayOrder(ProgramSeed.mondayId);

    await programs.reorderProgramExercises(
      ProgramSeed.mondayId,
      ids.reversed.toList(),
    );

    expect(dayOrder(ProgramSeed.mondayId), before.reversed.toList());
    expect(indexes(ProgramSeed.mondayId), [0, 1, 2, 3, 4, 5]);
  });

  test('reordering with a stale list is refused', () async {
    expect(
      () => programs.reorderProgramExercises(ProgramSeed.mondayId, ['nope']),
      throwsA(isA<InvalidStateException>()),
    );
  });

  test(
    'archiving removes the exercise from every day but keeps history',
    () async {
      final workouts = WorkoutLocalDataSource(harness.storage, programs);
      var id = 0;
      final session = await workouts.startSession(
        dayId: ProgramSeed.mondayId,
        now: now,
        newId: () => 'id${id++}',
      );

      await programs.archiveExercise('ex_squat');

      expect(dayOrder(ProgramSeed.mondayId), isNot(contains('ex_squat')));
      expect(indexes(ProgramSeed.mondayId), [0, 1, 2, 3, 4]);
      expect(
        programs.exercises().map((e) => e.id),
        isNot(contains('ex_squat')),
      );
      // Still resolvable for history and progress.
      expect(programs.requireExercise('ex_squat').isArchived, isTrue);
      expect(
        harness.storage.sessionExercises.values.where(
          (e) => e.sessionId == session.id && e.exerciseId == 'ex_squat',
        ),
        hasLength(1),
      );
    },
  );

  test('an archived exercise cannot be added to a day', () async {
    final entry = programs.programExercisesForDay(ProgramSeed.mondayId).first;
    await programs.archiveExercise(entry.exerciseId);

    expect(
      () => programs.saveProgramExercise(entry),
      throwsA(isA<InvalidStateException>()),
    );
  });

  test('days using an exercise are listed in week order', () {
    final days = programs.daysUsing('ex_squat');

    expect(days.map((d) => d.id), [ProgramSeed.mondayId]);
  });

  test('the same exercise cannot be added to a day twice', () async {
    final existing = programs
        .programExercisesForDay(ProgramSeed.mondayId)
        .first;

    expect(
      () => programs.saveProgramExercise(
        ProgramExercise(
          id: 'pe_dupe',
          workoutDayId: ProgramSeed.mondayId,
          exerciseId: existing.exerciseId,
          orderIndex: 6,
          workingSets: 3,
          repMin: 6,
          repMax: 10,
          restMinSeconds: 120,
          restMaxSeconds: 180,
          rirMin: 1,
          rirMax: 3,
          weightStep: 1,
        ),
      ),
      throwsA(isA<InvalidStateException>()),
    );
    // Updating the existing entry is still fine.
    await programs.saveProgramExercise(existing.copyWith(workingSets: 5));
  });

  test('two custom exercises cannot share a name', () async {
    final squat = programs.requireExercise('ex_squat');

    expect(
      () => programs.saveExercise(
        Exercise(
          id: 'ex_custom_1',
          name: ' squat / hack squat ',
          primaryMuscle: squat.primaryMuscle,
          category: squat.category,
          isCustom: true,
          createdAt: now,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  group('supersets', () {
    const thursday = ProgramSeed.thursdayId;

    Map<String, int?> groups() => {
      for (final p in programs.programExercisesForDay(thursday))
        p.exerciseId: p.supersetGroup,
    };

    test('removing one member dissolves the group', () async {
      final triceps = programs
          .programExercisesForDay(thursday)
          .firstWhere((p) => p.exerciseId == 'ex_overhead_triceps_extension');

      await programs.removeProgramExercise(triceps.id);

      expect(groups()['ex_incline_dumbbell_curl'], isNull);
      // The other superset is untouched.
      expect(groups()['ex_hammer_curl'], 2);
    });

    test('a reorder that splits a group dissolves it', () async {
      final ids = [
        for (final p in programs.programExercisesForDay(thursday)) p.id,
      ];
      // Move the first superset-1 member (index 3) to the top.
      final moved = [ids[3], ...ids.take(3), ...ids.skip(4)];

      await programs.reorderProgramExercises(thursday, moved);

      expect(groups()['ex_overhead_triceps_extension'], isNull);
      expect(groups()['ex_incline_dumbbell_curl'], isNull);
      expect(groups()['ex_straight_bar_pushdown'], 2);
    });

    test('joining a group moves the exercise next to its partner', () async {
      final lateral = programs
          .programExercisesForDay(thursday)
          .firstWhere((p) => p.exerciseId == 'ex_dumbbell_lateral_raise');

      await programs.saveProgramExercise(lateral.copyWith(supersetGroup: 2));

      final order = [
        for (final p in programs.programExercisesForDay(thursday)) p.exerciseId,
      ];
      expect(order.sublist(order.length - 3), [
        'ex_straight_bar_pushdown',
        'ex_hammer_curl',
        'ex_dumbbell_lateral_raise',
      ]);
      expect(
        [
          for (final p in programs.programExercisesForDay(thursday))
            p.orderIndex,
        ],
        [0, 1, 2, 3, 4, 5, 6],
      );
    });
  });

  test('a rest day with exercises adds no planned volume', () async {
    final progress = ProgressRepositoryImpl(
      programs,
      WorkoutLocalDataSource(harness.storage, programs),
      BodyWeightLocalDataSource(harness.storage),
    );
    Future<Set<MuscleGroup>> plannedMuscles() async {
      final data =
          (await progress.watchProgressData().first)
              as ApiSuccess<ProgressData>;
      return {for (final c in data.data.plannedConfig) c.muscle};
    }

    expect(await plannedMuscles(), contains(MuscleGroup.quads));

    final monday = programs.requireDay(ProgramSeed.mondayId);
    await programs.saveWorkoutDay(monday.copyWith(type: DayType.rest));

    expect(await plannedMuscles(), isNot(contains(MuscleGroup.quads)));
    expect(programs.daysUsing('ex_squat'), isEmpty);
  });

  group('restore', () {
    test('brings an archived exercise back, keeping its media', () async {
      final squat = programs.requireExercise('ex_squat');
      await programs.saveExercise(squat.copyWith(imagePaths: ['squat.jpg']));
      await programs.archiveExercise('ex_squat');

      await programs.restoreExercise('ex_squat');

      final restored = programs.requireExercise('ex_squat');
      expect(restored.isArchived, isFalse);
      expect(restored.imagePaths, ['squat.jpg']);
      expect(programs.exercises().map((e) => e.id), contains('ex_squat'));
      // Not silently put back into a day.
      expect(programs.daysUsing('ex_squat'), isEmpty);
    });

    test('is refused when another exercise took the name', () async {
      final squat = programs.requireExercise('ex_squat');
      await programs.archiveExercise('ex_squat');
      await programs.saveExercise(
        Exercise(
          id: 'ex_custom_1',
          name: squat.name,
          primaryMuscle: squat.primaryMuscle,
          category: squat.category,
          isCustom: true,
          createdAt: now,
        ),
      );

      expect(
        () => programs.restoreExercise('ex_squat'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  test('the exercise screen skips photos whose files are gone', () async {
    final squat = programs.requireExercise('ex_squat');
    await programs.saveExercise(
      squat.copyWith(imagePaths: ['kept.jpg', 'gone.jpg']),
    );
    final repository = ExerciseRepositoryImpl(
      programs,
      FakeMediaStore(files: {'kept.jpg'}),
    );

    final details =
        (await repository.watchDetails('ex_squat').first)
            as ApiSuccess<ExerciseDetails>;

    expect(details.data.images.map((i) => i.fileName), ['kept.jpg']);
  });

  test('an 11th photo is refused when saving', () async {
    final squat = programs.requireExercise('ex_squat');

    expect(
      () => programs.saveExercise(
        squat.copyWith(imagePaths: [for (var i = 0; i < 11; i++) '$i.jpg']),
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
