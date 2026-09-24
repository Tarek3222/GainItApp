import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/services/media_store.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_details.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_filter.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_input.dart';
import 'package:gainit/features/exercises/domain/repositories/exercise_guide_repository.dart';
import 'package:gainit/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:gainit/features/exercises/domain/usecases/exercise_use_cases.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_media_store.dart';
import '../../helpers/fixed_clock.dart';

class _MockExerciseRepository extends Mock implements ExerciseRepository {}

class _MockGuideRepository extends Mock implements ExerciseGuideRepository {}

class _FixedIds implements IdGenerator {
  @override
  String next() => 'abc';
}

void main() {
  late _MockExerciseRepository repository;
  final clock = FixedClock(DateTime(2026, 3, 1));

  final curl = Exercise(
    id: 'ex_curl',
    name: 'Curl',
    primaryMuscle: MuscleGroup.biceps,
    category: ExerciseCategory.isolation,
    createdAt: DateTime(2026),
    imagePath: 'old.jpg',
  );

  Exercise saved() =>
      verify(() => repository.saveExercise(captureAny())).captured.last
          as Exercise;

  setUpAll(() => registerFallbackValue(curl));

  setUp(() {
    repository = _MockExerciseRepository();
    when(
      () => repository.saveExercise(any()),
    ).thenAnswer((_) async => voidSuccess);
    when(
      () => repository.getExercise('ex_curl'),
    ).thenAnswer((_) async => ApiSuccess(curl));
  });

  group('SaveExerciseUseCase', () {
    SaveExerciseUseCase useCase() =>
        SaveExerciseUseCase(repository, clock, _FixedIds());

    test('creates a custom exercise and returns its ID', () async {
      final result = await useCase()(
        const ExerciseInput(
          name: '  Cable Curl ',
          primaryMuscle: MuscleGroup.biceps,
          // The main muscle is dropped from the secondary list.
          secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.forearms],
          category: ExerciseCategory.isolation,
          instructions: '  ',
        ),
      );

      expect((result as ApiSuccess<String>).data, 'ex_custom_abc');
      final exercise = saved();
      expect(exercise.name, 'Cable Curl');
      expect(exercise.isCustom, isTrue);
      expect(exercise.secondaryMuscles, [MuscleGroup.forearms]);
      expect(exercise.instructions, isNull);
      expect(exercise.createdAt, clock.now());
    });

    test('updates an existing exercise and keeps its ID and media', () async {
      final result = await useCase()(
        const ExerciseInput(
          name: 'Bayesian Curl',
          primaryMuscle: MuscleGroup.biceps,
          category: ExerciseCategory.isolation,
          instructions: 'Face away from the cable.',
        ),
        existing: curl,
      );

      expect((result as ApiSuccess<String>).data, 'ex_curl');
      final exercise = saved();
      expect(exercise.name, 'Bayesian Curl');
      expect(exercise.imagePath, 'old.jpg');
      expect(exercise.instructions, 'Face away from the cable.');
    });

    test('rejects an empty name without saving', () async {
      final result = await useCase()(
        const ExerciseInput(
          name: ' ',
          primaryMuscle: MuscleGroup.chest,
          category: ExerciseCategory.compound,
        ),
      );

      expect((result as ApiFailure<String>).failure, isA<ValidationFailure>());
      verifyNever(() => repository.saveExercise(any()));
    });
  });

  group('AttachExerciseMediaUseCase', () {
    test('a new photo replaces the old file', () async {
      final media = FakeMediaStore(pickResult: const ApiSuccess('new.jpg'));

      final result = await AttachExerciseMediaUseCase(repository, media)(
        'ex_curl',
        ExerciseMediaKind.image,
        MediaSource.gallery,
      );

      expect(result.isSuccess, isTrue);
      expect(saved().imagePath, 'new.jpg');
      expect(media.deleted, ['old.jpg']);
    });

    test('a video is stored alongside the photo', () async {
      final media = FakeMediaStore(pickResult: const ApiSuccess('demo.mp4'));

      await AttachExerciseMediaUseCase(repository, media)(
        'ex_curl',
        ExerciseMediaKind.video,
        MediaSource.camera,
      );

      final exercise = saved();
      expect(exercise.videoPath, 'demo.mp4');
      expect(exercise.imagePath, 'old.jpg');
      expect(media.deleted, isEmpty);
    });

    test('cancelling changes nothing', () async {
      final media = FakeMediaStore();

      await AttachExerciseMediaUseCase(repository, media)(
        'ex_curl',
        ExerciseMediaKind.image,
        MediaSource.camera,
      );

      verifyNever(() => repository.saveExercise(any()));
    });

    test('if saving fails the new file is removed', () async {
      when(
        () => repository.saveExercise(any()),
      ).thenAnswer((_) async => const ApiFailure(StorageFailure()));
      final media = FakeMediaStore(pickResult: const ApiSuccess('new.jpg'));

      final result = await AttachExerciseMediaUseCase(repository, media)(
        'ex_curl',
        ExerciseMediaKind.image,
        MediaSource.gallery,
      );

      expect(result, isA<ApiFailure<void>>());
      expect(media.deleted, ['new.jpg']);
    });
  });

  test('removing a photo clears it and deletes the file', () async {
    final media = FakeMediaStore();

    await RemoveExerciseMediaUseCase(repository, media)(
      'ex_curl',
      ExerciseMediaKind.image,
    );

    expect(saved().imagePath, isNull);
    expect(media.deleted, ['old.jpg']);
  });

  group('ExerciseFilter', () {
    final bench = Exercise(
      id: 'b',
      name: 'Bench Press',
      primaryMuscle: MuscleGroup.chest,
      secondaryMuscles: const [MuscleGroup.triceps],
      category: ExerciseCategory.compound,
      createdAt: DateTime(2026),
    );

    test('matches name text case-insensitively', () {
      expect(const ExerciseFilter(query: 'bench').matches(bench), isTrue);
      expect(const ExerciseFilter(query: 'squat').matches(bench), isFalse);
    });

    test('matches main and secondary muscles', () {
      expect(
        const ExerciseFilter(muscle: MuscleGroup.triceps).matches(bench),
        isTrue,
      );
      expect(
        const ExerciseFilter(muscle: MuscleGroup.quads).matches(bench),
        isFalse,
      );
    });
  });

  test('a guide that fails to load still shows the exercise', () async {
    final details = ExerciseDetails(exercise: curl, usedInDays: const []);
    when(
      () => repository.watchDetails('ex_curl'),
    ).thenAnswer((_) => Stream.value(ApiSuccess(details)));
    final guides = _MockGuideRepository();
    when(() => guides.guideFor('ex_curl')).thenAnswer(
      (_) async => const ApiFailure(UnexpectedFailure('broken asset')),
    );

    final result = await WatchExerciseDetailsUseCase(repository, guides)(
      'ex_curl',
    ).first;

    expect((result as ApiSuccess<ExerciseDetails>).data.exercise, curl);
    expect(result.data.guide, isNull);
    expect(result.data.guideUnavailable, isTrue);
  });
}
