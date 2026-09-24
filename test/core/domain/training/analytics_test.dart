import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/body_weight_entry.dart';
import 'package:gainit/core/domain/training/body_weight_trend.dart';
import 'package:gainit/core/domain/training/one_rep_max.dart';
import 'package:gainit/core/domain/training/performance.dart';
import 'package:gainit/core/domain/training/performance_comparator.dart';

ExerciseSessionPerformance perf(List<(double, int)> sets) =>
    ExerciseSessionPerformance(
      sessionId: 'x',
      date: DateTime(2026),
      sets: [for (final (w, r) in sets) SetPerformance(weight: w, reps: r)],
    );

BodyWeightEntry weight(DateTime at, double kg) =>
    BodyWeightEntry(id: '$at', weightKg: kg, measuredAt: at);

void main() {
  group('OneRepMax.epley', () {
    test('returns the weight for a single rep', () {
      expect(OneRepMax.epley(100, 1), 100);
    });

    test('estimates from reps', () {
      expect(OneRepMax.epley(100, 10), 133.3);
    });

    test('returns 0 for zero reps', () {
      expect(OneRepMax.epley(100, 0), 0);
    });
  });

  group('PerformanceComparator', () {
    test('reports first time without a previous session', () {
      final result = PerformanceComparator.compare(current: perf([(30, 10)]));
      expect(result.outcome, ProgressOutcome.firstTime);
    });

    test('reports reps gained at the same weight', () {
      final result = PerformanceComparator.compare(
        current: perf([(30, 11), (30, 10), (30, 9)]),
        previous: perf([(30, 10), (30, 9), (30, 8)]),
      );
      expect(result.outcome, ProgressOutcome.repsIncreased);
      expect(result.repsDelta, 3);
    });

    test('reports a weight increase', () {
      final result = PerformanceComparator.compare(
        current: perf([(32.5, 6)]),
        previous: perf([(30, 10)]),
      );
      expect(result.outcome, ProgressOutcome.weightIncreased);
      expect(result.weightDelta, 2.5);
    });

    test('reports maintained performance', () {
      final result = PerformanceComparator.compare(
        current: perf([(30, 10)]),
        previous: perf([(30, 10)]),
      );
      expect(result.outcome, ProgressOutcome.maintained);
    });
  });

  group('BodyWeightTrend', () {
    test('summary returns null without entries', () {
      expect(BodyWeightTrend.summary(const []), isNull);
    });

    test('summary compares against the entry at the start of the period', () {
      final summary = BodyWeightTrend.summary([
        weight(DateTime(2026, 9, 1), 71.8),
        weight(DateTime(2026, 9, 8), 72.1),
        weight(DateTime(2026, 9, 15), 72.4),
        weight(DateTime(2026, 9, 22), 72.5),
      ]);

      expect(summary!.latest.weightKg, 72.5);
      expect(summary.changeOverPeriod, 0.4);
    });

    test('rolling average smooths within the window', () {
      final points = BodyWeightTrend.rollingAverage([
        weight(DateTime(2026, 9, 1), 70),
        weight(DateTime(2026, 9, 2), 72),
        weight(DateTime(2026, 9, 20), 74),
      ]);

      expect(points.map((p) => p.weightKg), [70, 71, 74]);
    });
  });
}
