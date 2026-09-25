import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../domain/entities/exercise_guide.dart';
import '../../domain/repositories/exercise_guide_repository.dart';

typedef AssetLoader = Future<String> Function(String path);

/// Guides bundled as JSON (`assets/exercise_guides/<language>.json`),
/// keyed by exercise ID. Each language is parsed once and cached.
class ExerciseGuideRepositoryImpl implements ExerciseGuideRepository {
  ExerciseGuideRepositoryImpl(this._load);

  static const _fallbackLanguage = 'en';

  final AssetLoader _load;
  final _guides = <String, Future<Map<String, ExerciseGuide>>>{};

  static String assetPath(String languageCode) =>
      'assets/exercise_guides/$languageCode.json';

  @override
  Future<ApiResult<ExerciseGuide?>> guideFor(
    String exerciseId, {
    String languageCode = _fallbackLanguage,
  }) async {
    final translated = await _guideIn(languageCode, exerciseId);
    final found = switch (translated) {
      ApiSuccess(:final data) => data != null,
      ApiFailure() => false,
    };
    if (languageCode == _fallbackLanguage || found) return translated;
    // Not translated (or the file is broken): show the English guide.
    return _guideIn(_fallbackLanguage, exerciseId);
  }

  Future<ApiResult<ExerciseGuide?>> _guideIn(
    String languageCode,
    String exerciseId,
  ) async {
    try {
      final guides = await (_guides[languageCode] ??= _parse(languageCode));
      return ApiSuccess(guides[exerciseId]);
    } on Object catch (error) {
      // A broken asset must not break the exercise screen; retry next time.
      // The removed future already failed; drop it without rethrowing.
      _guides.remove(languageCode)?.ignore();
      if (kDebugMode) debugPrint('ExerciseGuideRepository: $error');
      return const ApiFailure(
        UnexpectedFailure('Could not load the exercise guide.'),
      );
    }
  }

  Future<Map<String, ExerciseGuide>> _parse(String languageCode) async {
    final json =
        jsonDecode(await _load(assetPath(languageCode)))
            as Map<String, dynamic>;
    final references = (json['references'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    List<String> lines(Map<String, dynamic> entry, String key) => [
      for (final line in entry[key] as List<dynamic>? ?? const [])
        line as String,
    ];
    final exercises = json['exercises'] as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in exercises.entries)
        key: () {
          final entry = value as Map<String, dynamic>;
          return ExerciseGuide(
            exerciseName: entry['name'] as String? ?? '',
            setup: lines(entry, 'setup'),
            execution: lines(entry, 'execution'),
            tips: lines(entry, 'tips'),
            mistakes: lines(entry, 'mistakes'),
            evidence: [
              for (final e in entry['evidence'] as List<dynamic>? ?? const [])
                GuideEvidence(
                  finding: (e as Map<String, dynamic>)['finding'] as String,
                  citation:
                      references[e['ref'] as String] ??
                      (throw FormatException('Unknown reference ${e['ref']}')),
                ),
            ],
          );
        }(),
    };
  }
}
