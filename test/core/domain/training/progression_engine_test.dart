import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/training/performance.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';

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
}
