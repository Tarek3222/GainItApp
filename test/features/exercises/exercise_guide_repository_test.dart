import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/storage/seed/program_seed.dart';
import 'package:gainit/features/exercises/data/repositories/exercise_guide_repository_impl.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_guide.dart';

void main() {
  final repository = ExerciseGuideRepositoryImpl(
    (path) => File(path).readAsString(),
  );

  test('every seeded exercise has a complete, cited guide', () async {
    final seed = ProgramSeed.build(DateTime(2026));

    for (final exercise in seed.exercises) {
      final result = await repository.guideFor(exercise.id);
      final guide = (result as ApiSuccess<ExerciseGuide?>).data;

      expect(guide, isNotNull, reason: exercise.id);
      expect(guide!.setup, isNotEmpty, reason: exercise.id);
      expect(guide.execution, isNotEmpty, reason: exercise.id);
      expect(guide.tips, isNotEmpty, reason: exercise.id);
      expect(guide.mistakes, isNotEmpty, reason: exercise.id);
      expect(guide.evidence, isNotEmpty, reason: exercise.id);
      for (final e in guide.evidence) {
        expect(e.citation, matches(RegExp(r'\(\d{4}\)')), reason: exercise.id);
      }
    }
  });

  test('custom exercises have no bundled guide', () async {
    final result = await repository.guideFor('ex_custom_123');

    expect((result as ApiSuccess<ExerciseGuide?>).data, isNull);
  });

  test('a broken guide file is reported, not thrown', () async {
    final broken = ExerciseGuideRepositoryImpl((_) async => '{"exercises":');

    final result = await broken.guideFor('ex_squat');

    expect(result, isA<ApiFailure<ExerciseGuide?>>());
  });

  test('an evidence entry citing an unknown reference is rejected', () async {
    final unknownRef = ExerciseGuideRepositoryImpl(
      (_) async => '''
{"references": {}, "exercises": {"ex_a": {"evidence": [{"finding": "x", "ref": "missing"}]}}}
''',
    );

    final result = await unknownRef.guideFor('ex_a');

    expect(result, isA<ApiFailure<ExerciseGuide?>>());
  });
}
