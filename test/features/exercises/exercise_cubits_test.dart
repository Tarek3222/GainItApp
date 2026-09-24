import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/presentation/action_outcome.dart';
import 'package:gainit/core/presentation/view_state.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_details.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_guide.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_input.dart';
import 'package:gainit/features/exercises/domain/usecases/exercise_use_cases.dart';
import 'package:gainit/features/exercises/presentation/cubits/exercise_cubits.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet extends Mock implements GetExerciseUseCase {}

class _MockSave extends Mock implements SaveExerciseUseCase {}

class _MockWatchDetails extends Mock implements WatchExerciseDetailsUseCase {}

class _MockAttach extends Mock implements AttachExerciseMediaUseCase {}

class _MockRemove extends Mock implements RemoveExerciseMediaUseCase {}

class _MockArchive extends Mock implements ArchiveExerciseUseCase {}

class _MockRestore extends Mock implements RestoreExerciseUseCase {}

void main() {
  final curl = Exercise(
    id: 'ex_curl',
    name: 'Curl',
    primaryMuscle: MuscleGroup.biceps,
    category: ExerciseCategory.isolation,
    createdAt: DateTime(2026),
  );
  const input = ExerciseInput(
    name: 'Curl',
    primaryMuscle: MuscleGroup.biceps,
    category: ExerciseCategory.isolation,
  );

  late _MockGet get;
  late _MockSave save;

  setUpAll(() => registerFallbackValue(input));

  setUp(() {
    get = _MockGet();
    save = _MockSave();
    when(
      () => save(any(), existing: any(named: 'existing')),
    ).thenAnswer((_) async => const ApiSuccess('id'));
  });

  group('ExerciseEditorCubit', () {
    blocTest<ExerciseEditorCubit, ViewState<Exercise?>>(
      'a new exercise loads empty and saves without an existing one',
      build: () => ExerciseEditorCubit(
        exerciseId: null,
        getExercise: get,
        saveExercise: save,
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.save(input);
      },
      expect: () => [
        const ViewLoading<Exercise?>(),
        const ViewLoaded<Exercise?>(null),
      ],
      verify: (_) {
        verify(() => save(input, existing: null)).called(1);
        verifyNever(() => get(any()));
      },
    );

    blocTest<ExerciseEditorCubit, ViewState<Exercise?>>(
      'editing saves over the loaded exercise',
      build: () {
        when(() => get('ex_curl')).thenAnswer((_) async => ApiSuccess(curl));
        return ExerciseEditorCubit(
          exerciseId: 'ex_curl',
          getExercise: get,
          saveExercise: save,
        );
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.save(input);
      },
      verify: (_) => verify(() => save(input, existing: curl)).called(1),
    );

    test('editing refuses to save before the exercise has loaded', () async {
      final cubit = ExerciseEditorCubit(
        exerciseId: 'ex_curl',
        getExercise: get,
        saveExercise: save,
      );

      final outcome = await cubit.save(input);

      expect(outcome, isA<ActionFailed<String>>());
      verifyNever(() => save(any(), existing: any(named: 'existing')));
      await cubit.close();
    });
  });

  group('ExerciseDetailsCubit', () {
    ExerciseDetailsCubit build({
      required _MockArchive archive,
      _MockRestore? restore,
      ExerciseGuide? guide,
    }) {
      final watch = _MockWatchDetails();
      when(() => watch('ex_curl')).thenAnswer(
        (_) => Stream.value(
          ApiSuccess(
            ExerciseDetails(exercise: curl, usedInDays: const [], guide: guide),
          ),
        ),
      );
      return ExerciseDetailsCubit(
        exerciseId: 'ex_curl',
        watchDetails: watch,
        attachMedia: _MockAttach(),
        removeMedia: _MockRemove(),
        archive: archive,
        restore: restore ?? _MockRestore(),
      );
    }

    test('archive forwards the exercise ID', () async {
      final archive = _MockArchive();
      when(() => archive('ex_curl')).thenAnswer((_) async => voidSuccess);
      final cubit = build(archive: archive)..start();

      final outcome = await cubit.archive();

      expect(outcome, isA<ActionDone<void>>());
      verify(() => archive('ex_curl')).called(1);
      await cubit.close();
    });

    test('restore forwards the exercise ID', () async {
      final restore = _MockRestore();
      when(() => restore('ex_curl')).thenAnswer((_) async => voidSuccess);
      final cubit = build(archive: _MockArchive(), restore: restore)..start();

      final outcome = await cubit.restore();

      expect(outcome, isA<ActionDone<void>>());
      verify(() => restore('ex_curl')).called(1);
      await cubit.close();
    });

    test('a renamed built-in exercise flags its guide as for the original', () {
      const guide = ExerciseGuide(
        exerciseName: 'Hammer Curl',
        setup: [],
        execution: [],
        tips: [],
        mistakes: [],
        evidence: [],
      );

      final renamed = ExerciseDetails(
        exercise: curl,
        usedInDays: const [],
        guide: guide,
      );
      final same = ExerciseDetails(
        exercise: curl.copyWith(name: 'Hammer Curl'),
        usedInDays: const [],
        guide: guide,
      );

      expect(renamed.guideIsForOriginal, isTrue);
      expect(same.guideIsForOriginal, isFalse);
    });
  });
}
