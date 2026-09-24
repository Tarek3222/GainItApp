import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/training/performance.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';
import 'package:gainit/core/domain/units/unit_converter.dart';

ExerciseSessionPerformance session(
  List<(double, int)> sets, {
  int daysAgo = 0,
}) {
  return ExerciseSessionPerformance(
    sessionId: 's$daysAgo',
    date: DateTime(2026, 1, 30).subtract(Duration(days: daysAgo)),
    sets: [for (final (w, r) in sets) SetPerformance(weight: w, reps: r)],
  );
}

void main() {
  const engine = ProgressionEngine();
  const bench = ProgressionConfig(
    workingSets: 3,
    repMin: 6,
    repMax: 10,
    weightStep: 2.5,
  );

  group('ProgressionEngine.recommend', () {
    test('returns firstSession with the configured range when no history', () {
      final result = engine.recommend(config: bench, history: const []);

      expect(result.type, RecommendationType.firstSession);
      expect(result.suggestedWeight, isNull);
      expect(result.repMin, 6);
      expect(result.repMax, 10);
    });

    test('increases weight by the step when all sets reach rep max', () {
      final result = engine.recommend(
        config: bench,
        history: [
          session([(30, 10), (30, 10), (30, 10)]),
        ],
      );

      expect(result.type, RecommendationType.increaseWeight);
      expect(result.suggestedWeight, 32.5);
      expect(result.targetReps, 6);
    });

    test(
      'keeps weight and targets lowest set + 1 when not all sets at max',
      () {
        final result = engine.recommend(
          config: bench,
          history: [
            session([(30, 10), (30, 10), (30, 9)]),
          ],
        );

        expect(result.type, RecommendationType.addReps);
        expect(result.suggestedWeight, 30);
        expect(result.targetReps, 10);
      },
    );

    test(
      'does not increase weight when fewer sets than configured were done',
      () {
        final result = engine.recommend(
          config: bench,
          history: [
            session([(30, 10), (30, 10)]),
          ],
        );

        expect(result.type, RecommendationType.addReps);
      },
    );

    test('target reps never exceed rep max nor fall below rep min', () {
      final low = engine.recommend(
        config: bench,
        history: [
          session([(30, 3), (30, 2), (30, 2)]),
        ],
      );

      expect(low.targetReps, 6);
    });

    test('uses a different configured weight step', () {
      const dumbbell = ProgressionConfig(
        workingSets: 2,
        repMin: 12,
        repMax: 15,
        weightStep: 2,
      );
      final result = engine.recommend(
        config: dumbbell,
        history: [
          session([(12, 15), (12, 15)]),
        ],
      );

      expect(result.suggestedWeight, 14);
    });

    test('recommends a ~10% deload after 3 sessions without progress', () {
      final result = engine.recommend(
        config: bench,
        history: [
          session([(40, 8), (40, 7), (40, 7)], daysAgo: 0),
          session([(40, 8), (40, 7), (40, 7)], daysAgo: 7),
          session([(40, 8), (40, 8), (40, 7)], daysAgo: 14),
        ],
      );

      expect(result.type, RecommendationType.deload);
      expect(result.suggestedWeight, 35);
    });

    test('does not deload when the latest session improved', () {
      final result = engine.recommend(
        config: bench,
        history: [
          session([(40, 9), (40, 8), (40, 7)], daysAgo: 0),
          session([(40, 8), (40, 7), (40, 7)], daysAgo: 7),
          session([(40, 8), (40, 7), (40, 7)], daysAgo: 14),
        ],
      );

      expect(result.type, RecommendationType.addReps);
    });

    test('deload always goes below the current weight', () {
      final result = engine.recommend(
        config: bench,
        history: [
          session([(5, 6), (5, 6), (5, 6)], daysAgo: 0),
          session([(5, 6), (5, 6), (5, 6)], daysAgo: 7),
          session([(5, 6), (5, 6), (5, 6)], daysAgo: 14),
        ],
      );

      expect(result.suggestedWeight, lessThan(5));
      expect(result.suggestedWeight, greaterThanOrEqualTo(0));
    });

    test('an off-grid weight increases by at most one step', () {
      const oneKg = ProgressionConfig(
        workingSets: 3,
        repMin: 6,
        repMax: 10,
        weightStep: 1,
      );
      final result = engine.recommend(
        config: oneKg,
        history: [
          session([(32.5, 10), (32.5, 10), (32.5, 10)]),
        ],
      );

      expect(result.type, RecommendationType.increaseWeight);
      expect(result.suggestedWeight, 33);
    });

    test('sessions logged at 0 kg count as no history', () {
      final result = engine.recommend(
        config: bench,
        history: [
          session([(0, 8), (0, 8), (0, 8)]),
        ],
      );

      expect(result.type, RecommendationType.firstSession);
      expect(result.suggestedWeight, isNull);
    });

    test('deload never suggests a weight below one step', () {
      const oneKg = ProgressionConfig(
        workingSets: 3,
        repMin: 6,
        repMax: 10,
        weightStep: 1,
      );
      List<ExerciseSessionPerformance> stalledAt(double w) => [
        session([(w, 6), (w, 6), (w, 6)], daysAgo: 0),
        session([(w, 6), (w, 6), (w, 6)], daysAgo: 7),
        session([(w, 6), (w, 6), (w, 6)], daysAgo: 14),
      ];

      expect(
        engine.recommend(config: oneKg, history: stalledAt(1)).suggestedWeight,
        1,
      );
      expect(
        engine.recommend(config: oneKg, history: stalledAt(2)).suggestedWeight,
        1,
      );
    });

    test('follows the spec example sessions 1 → 4', () {
      final history = [
        session([(30, 10), (30, 10), (30, 10)], daysAgo: 0),
        session([(30, 10), (30, 10), (30, 9)], daysAgo: 7),
        session([(30, 10), (30, 9), (30, 8)], daysAgo: 14),
      ];

      final result = engine.recommend(config: bench, history: history);

      expect(result.type, RecommendationType.increaseWeight);
      expect(result.suggestedWeight, 32.5);
      expect(result.repMin, 6);
      expect(result.repMax, 10);
    });
  });

  group('ProgressionEngine rounding', () {
    test('roundToStep snaps to the nearest step without float noise', () {
      expect(ProgressionEngine.roundToStep(32.4999, 2.5), 32.5);
      expect(ProgressionEngine.roundToStep(0.1 + 0.2, 0.1), 0.3);
    });

    test('roundDownToStep floors to the step', () {
      expect(ProgressionEngine.roundDownToStep(36, 2.5), 35);
      expect(ProgressionEngine.roundDownToStep(30, 2.5), 30);
    });
  });

  group('imperial progression', () {
    const oneKgImperial = ProgressionConfig(
      workingSets: 3,
      repMin: 6,
      repMax: 10,
      weightStep: 1,
      unitSystem: UnitSystem.imperial,
    );
    double lb(double pounds) => UnitConverter.lbToKg(pounds);
    double inPounds(double? kg) =>
        double.parse(UnitConverter.kgToLb(kg!).toStringAsFixed(2));

    test('adds a whole-pound step (1 kg ≈ 2 lb) on the lb grid', () {
      final result = engine.recommend(
        config: oneKgImperial,
        history: [
          session([(lb(132), 10), (lb(132), 10), (lb(132), 10)]),
        ],
      );

      expect(result.type, RecommendationType.increaseWeight);
      expect(inPounds(result.suggestedWeight), 134);
      expect(inPounds(result.previousWeight), 132);
    });

    test('keeps the logged pound value when adding reps', () {
      final result = engine.recommend(
        config: oneKgImperial,
        history: [
          session([(lb(135), 8), (lb(135), 7), (lb(135), 7)]),
        ],
      );

      expect(result.type, RecommendationType.addReps);
      expect(inPounds(result.suggestedWeight), 135);
      expect(result.targetReps, 8);
    });
  });

  test('loads within 0.01 kg count as the same weight', () {
    final result = engine.recommend(
      config: bench,
      history: [
        session([(59.874, 10), (59.87401, 10), (59.874, 10)]),
      ],
    );

    expect(result.type, RecommendationType.increaseWeight);
  });
}
