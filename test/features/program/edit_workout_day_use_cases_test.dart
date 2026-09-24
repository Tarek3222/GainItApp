import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';
import 'package:gainit/core/presentation/action_outcome.dart';
import 'package:gainit/core/presentation/view_state.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/features/program/domain/entities/plan_entities.dart';
import 'package:gainit/features/program/domain/repositories/program_repository.dart';
import 'package:gainit/features/program/domain/usecases/edit_workout_day_use_cases.dart';
import 'package:gainit/features/program/presentation/cubits/plan_cubits.dart';
import 'package:mocktail/mocktail.dart';

class _MockProgramRepository extends Mock implements ProgramRepository {}

class _MockWatchDay extends Mock implements WatchDayEditorUseCase {}

class _MockReorder extends Mock implements ReorderDayExercisesUseCase {}

class _FixedIds implements IdGenerator {
  @override
  String next() => 'n1';
}

void main() {
  late _MockProgramRepository repository;

  const monday = WorkoutDay(
    id: 'day_mon',
    programId: 'p',
    weekday: 1,
    name: 'Legs',
    type: DayType.workout,
    sortOrder: 2,
  );

  ProgramExercise entry(String id, int index) => ProgramExercise(
    id: id,
    workoutDayId: 'day_mon',
    exerciseId: 'ex_$id',
    orderIndex: index,
    workingSets: 3,
    repMin: 6,
    repMax: 10,
    restMinSeconds: 120,
    restMaxSeconds: 180,
    rirMin: 1,
    rirMax: 3,
    weightStep: 1,
  );

  ProgramExercise savedEntry() =>
      verify(() => repository.saveDayExercise(captureAny())).captured.single
          as ProgramExercise;

  setUpAll(() {
    registerFallbackValue(monday);
    registerFallbackValue(entry('x', 0));
  });

  setUp(() {
    repository = _MockProgramRepository();
    when(() => repository.saveDay(any())).thenAnswer((_) async => voidSuccess);
    when(
      () => repository.saveDayExercise(any()),
    ).thenAnswer((_) async => voidSuccess);
    when(
      () => repository.getDay('day_mon'),
    ).thenAnswer((_) async => const ApiSuccess(monday));
    when(
      () => repository.exerciseCount('day_mon'),
    ).thenAnswer((_) async => const ApiSuccess(4));
  });

  test('the day editor reads the plan without workout history', () async {
    when(
      () => repository.watchWorkoutDay('day_mon', withHistory: false),
    ).thenAnswer(
      (_) => Stream.value(
        const ApiSuccess(WorkoutDayData(day: monday, items: [])),
      ),
    );

    final result = await WatchDayEditorUseCase(repository)('day_mon').first;

    expect((result as ApiSuccess<WorkoutOverview>).data.day, monday);
    verifyNever(() => repository.watchWorkoutDay('day_mon'));
  });

  group('UpdateWorkoutDayUseCase', () {
    test('renames and switches the day type', () async {
      final result = await UpdateWorkoutDayUseCase(repository)(
        'day_mon',
        name: ' Lower body ',
        type: DayType.rest,
      );

      expect(result.isSuccess, isTrue);
      final saved =
          verify(() => repository.saveDay(captureAny())).captured.single
              as WorkoutDay;
      expect(saved.name, 'Lower body');
      expect(saved.type, DayType.rest);
    });

    test('rejects an empty name', () async {
      final result = await UpdateWorkoutDayUseCase(repository)(
        'day_mon',
        name: '  ',
      );

      expect((result as ApiFailure<void>).failure, isA<ValidationFailure>());
      verifyNever(() => repository.saveDay(any()));
    });
  });

  group('AddExerciseToDayUseCase', () {
    Future<void> add(ExerciseCategory category) async {
      when(() => repository.getExercise('ex_new')).thenAnswer(
        (_) async => ApiSuccess(
          Exercise(
            id: 'ex_new',
            name: 'New',
            primaryMuscle: MuscleGroup.quads,
            category: category,
            createdAt: DateTime(2026),
          ),
        ),
      );
      await AddExerciseToDayUseCase(repository, _FixedIds())(
        'day_mon',
        'ex_new',
      );
    }

    test('a compound gets 3 × 6–10 with 2–3 min rest, appended last', () async {
      await add(ExerciseCategory.compound);

      final e = savedEntry();
      expect(e.orderIndex, 4);
      expect((e.workingSets, e.repMin, e.repMax), (3, 6, 10));
      expect((e.restMinSeconds, e.restMaxSeconds), (120, 180));
      expect(e.weightStep, 1);
    });

    test('an isolation gets 3 × 10–15 with 60–90 s rest', () async {
      await add(ExerciseCategory.isolation);

      final e = savedEntry();
      expect((e.repMin, e.repMax), (10, 15));
      expect((e.restMinSeconds, e.restMaxSeconds), (60, 90));
    });
  });

  test('an invalid configuration is rejected before saving', () async {
    final result = await UpdateExerciseConfigUseCase(repository)(
      entry('a', 0).copyWith(repMin: 12, repMax: 8),
    );

    expect((result as ApiFailure<void>).failure, isA<ValidationFailure>());
    verifyNever(() => repository.saveDayExercise(any()));
  });

  group('WorkoutDayEditorCubit.move', () {
    late _MockReorder reorder;

    WorkoutOverview overview(List<String> ids) => WorkoutOverview(
      day: monday,
      exercises: [
        for (final (i, id) in ids.indexed)
          OverviewExercise(
            exerciseId: 'ex_$id',
            name: id,
            primaryMuscle: MuscleGroup.quads,
            config: entry(id, i),
            recommendation: const Recommendation(
              type: RecommendationType.firstSession,
              repMin: 6,
              repMax: 10,
              reason: '',
            ),
          ),
      ],
      totalSets: 9,
      plannedVolume: const {MuscleGroup.quads: 9},
      isInProgress: false,
    );

    setUp(() {
      reorder = _MockReorder();
      when(() => reorder(any(), any())).thenAnswer((_) async => voidSuccess);
    });

    WorkoutDayEditorCubit editor() {
      final watch = _MockWatchDay();
      when(
        () => watch('day_mon'),
      ).thenAnswer((_) => Stream.value(ApiSuccess(overview(['a', 'b', 'c']))));
      return WorkoutDayEditorCubit(
        dayId: 'day_mon',
        watchDay: watch,
        updateDay: UpdateWorkoutDayUseCase(repository),
        addExercise: AddExerciseToDayUseCase(repository, _FixedIds()),
        updateConfig: UpdateExerciseConfigUseCase(repository),
        removeExercise: RemoveExerciseFromDayUseCase(repository),
        reorder: reorder,
      );
    }

    List<String> shown(WorkoutDayEditorCubit cubit) => [
      for (final e
          in (cubit.state as ViewLoaded<WorkoutOverview>).data.exercises)
        e.name,
    ];

    test('shows the new order at once and chains quick moves', () async {
      final cubit = editor()..start();
      await pumpEventQueue();

      final first = cubit.move(0, 2);
      final second = cubit.move(0, 1);
      await Future.wait([first, second]);

      // a,b,c → b,c,a → c,b,a; each move builds on the previous one.
      expect(shown(cubit), ['c', 'b', 'a']);
      verifyInOrder([
        () => reorder('day_mon', ['b', 'c', 'a']),
        () => reorder('day_mon', ['c', 'b', 'a']),
      ]);
      await cubit.close();
    });

    test('a failed save restores the previous order', () async {
      when(
        () => reorder(any(), any()),
      ).thenAnswer((_) async => const ApiFailure(StorageFailure()));
      final cubit = editor()..start();
      await pumpEventQueue();

      final outcome = await cubit.move(0, 2);

      expect(outcome, isA<ActionFailed<void>>());
      expect(shown(cubit), ['a', 'b', 'c']);
      await cubit.close();
    });

    blocTest<WorkoutDayEditorCubit, ViewState<WorkoutOverview>>(
      'sends the full new order to the use case',
      build: () {
        final watch = _MockWatchDay();
        when(() => watch('day_mon')).thenAnswer(
          (_) => Stream.value(ApiSuccess(overview(['a', 'b', 'c']))),
        );
        return WorkoutDayEditorCubit(
          dayId: 'day_mon',
          watchDay: watch,
          updateDay: UpdateWorkoutDayUseCase(repository),
          addExercise: AddExerciseToDayUseCase(repository, _FixedIds()),
          updateConfig: UpdateExerciseConfigUseCase(repository),
          removeExercise: RemoveExerciseFromDayUseCase(repository),
          reorder: reorder,
        );
      },
      act: (cubit) async {
        cubit.start();
        await pumpEventQueue();
        await cubit.move(0, 2);
      },
      verify: (_) =>
          verify(() => reorder('day_mon', ['b', 'c', 'a'])).called(1),
    );
  });
}
