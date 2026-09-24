import 'package:equatable/equatable.dart';

import 'performance.dart';

enum ProgressOutcome {
  firstTime,
  weightIncreased,
  repsIncreased,
  maintained,
  regressed,
}

class PerformanceComparison extends Equatable {
  const PerformanceComparison({
    required this.outcome,
    this.weightDelta = 0,
    this.repsDelta = 0,
  });

  final ProgressOutcome outcome;
  final double weightDelta;
  final int repsDelta;

  bool get isImprovement =>
      outcome == ProgressOutcome.weightIncreased ||
      outcome == ProgressOutcome.repsIncreased;

  @override
  List<Object?> get props => [outcome, weightDelta, repsDelta];
}

/// Compares two sessions of the same exercise (spec §4.F "Progress").
abstract final class PerformanceComparator {
  static PerformanceComparison compare({
    required ExerciseSessionPerformance current,
    ExerciseSessionPerformance? previous,
  }) {
    if (previous == null || previous.isEmpty) {
      return const PerformanceComparison(outcome: ProgressOutcome.firstTime);
    }
    final weightDelta = current.topWeight - previous.topWeight;
    // Within 0.01 counts as the same load (unit-conversion rounding).
    if (weightDelta >= 0.01) {
      return PerformanceComparison(
        outcome: ProgressOutcome.weightIncreased,
        weightDelta: weightDelta,
      );
    }
    if (weightDelta <= -0.01) {
      return PerformanceComparison(
        outcome: ProgressOutcome.regressed,
        weightDelta: weightDelta,
      );
    }
    final repsDelta =
        current.totalRepsAtTopWeight - previous.totalRepsAtTopWeight;
    if (repsDelta > 0) {
      return PerformanceComparison(
        outcome: ProgressOutcome.repsIncreased,
        repsDelta: repsDelta,
      );
    }
    if (repsDelta < 0) {
      return PerformanceComparison(
        outcome: ProgressOutcome.regressed,
        repsDelta: repsDelta,
      );
    }
    return const PerformanceComparison(outcome: ProgressOutcome.maintained);
  }
}
