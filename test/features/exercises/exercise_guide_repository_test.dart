import 'dart:convert';
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

  test('every guide is translated to Arabic, line for line', () {
    Map<String, dynamic> read(String code) =>
        jsonDecode(File('assets/exercise_guides/$code.json').readAsStringSync())
            as Map<String, dynamic>;
    final en = read('en')['exercises'] as Map<String, dynamic>;
    final ar = read('ar')['exercises'] as Map<String, dynamic>;

    expect(ar.keys, en.keys);
    for (final id in en.keys) {
      final e = en[id] as Map<String, dynamic>;
      final a = ar[id] as Map<String, dynamic>;
      // The name identifies the built-in exercise, so it stays English.
      expect(a['name'], e['name'], reason: id);
      for (final section in ['setup', 'execution', 'tips', 'mistakes']) {
        expect(
          (a[section] as List).length,
          (e[section] as List).length,
          reason: '$id $section',
        );
      }
      expect(
        [for (final x in a['evidence'] as List) x['ref']],
        [for (final x in e['evidence'] as List) x['ref']],
        reason: id,
      );
    }
  });

  test('guides load in Arabic', () async {
    final result = await repository.guideFor('ex_squat', languageCode: 'ar');
    final guide = (result as ApiSuccess<ExerciseGuide?>).data!;

    expect(guide.setup.first, contains('قف'));
    // Citations name English-language papers and stay as they are.
    expect(guide.evidence.first.citation, contains('Kubo K'));
  });

  test('a guide missing in a language falls back to English', () async {
    final partial = ExerciseGuideRepositoryImpl(
      (path) async => path.endsWith('ar.json')
          ? '{"references": {}, "exercises": {}}'
          : File(path).readAsString(),
    );

    final result = await partial.guideFor('ex_squat', languageCode: 'ar');

    expect(
      (result as ApiSuccess<ExerciseGuide?>).data!.setup.first,
      startsWith('Stand'),
    );
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
