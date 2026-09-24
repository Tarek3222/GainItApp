import 'package:equatable/equatable.dart';

import 'performance.dart';

/// Exercise configuration the engine needs — read from stored program data,
/// never from `if (exercise == bench)` conditions.
class ProgressionConfig extends Equatable {
  const ProgressionConfig({
    required this.workingSets,
    required this.repMin,
    required this.repMax,
    required this.weightStep,
  });

  final int workingSets;
  final int repMin;
  final int repMax;
  final double weightStep;

  @override
  List<Object?> get props => [workingSets, repMin, repMax, weightStep];
}

enum RecommendationType {
  /// No previous data: pick a weight that fits the rep range.
  firstSession,

  /// Upper end of the rep range was hit on every working set.
  increaseWeight,

  /// Keep the load, add reps.
  addReps,

  /// Stalled for several sessions: reduce the load ~10% and rebuild.
  deload,
}

class Recommendation extends Equatable {
  const Recommendation({
    required this.type,
    required this.repMin,
    required this.repMax,
    required this.reason,
    this.suggestedWeight,
    this.previousWeight,
    this.targetReps,
  });

  final RecommendationType type;

  /// `null` when there is no history to base a load on.
  final double? suggestedWeight;
  final double? previousWeight;
  final int repMin;
  final int repMax;

  /// Reps to aim for on each set this session.
  final int? targetReps;
  final String reason;

  @override
  List<Object?> get props => [
    type,
    suggestedWeight,
    previousWeight,
    repMin,
    repMax,
    targetReps,
    reason,
  ];
}

/// Double progression (spec §12): pure Dart, no Flutter, no storage.
class ProgressionEngine {
  const ProgressionEngine({
    this.stallSessionsBeforeDeload = 2,
    this.deloadFactor = 0.9,
  });

  /// Number of consecutive non-improving sessions that trigger a deload.
  /// Two non-improving comparisons = three sessions at the same level.
  final int stallSessionsBeforeDeload;
  final double deloadFactor;

  /// [history] must be ordered most recent first and contain only completed
  /// sessions of this exercise.
  Recommendation recommend({
    required ProgressionConfig config,
    required List<ExerciseSessionPerformance> history,
  }) {
    // Sessions logged at 0 kg (allowed before sets required a weight) give
    // nothing to build a load on, so they count as no history.
    final sessions = history
        .where((h) => !h.isEmpty && h.topWeight > 0)
        .toList();
    if (sessions.isEmpty) {
      return Recommendation(
        type: RecommendationType.firstSession,
        repMin: config.repMin,
        repMax: config.repMax,
        targetReps: config.repMin,
        reason:
            'No history yet. Pick a weight you can lift for '
            '${config.repMin}–${config.repMax} reps.',
      );
    }

    final last = sessions.first;
    final weight = last.topWeight;

    if (_reachedTopOfRange(last, config)) {
      return Recommendation(
        type: RecommendationType.increaseWeight,
        suggestedWeight: _increasedWeight(weight, config.weightStep),
        previousWeight: weight,
        repMin: config.repMin,
        repMax: config.repMax,
        targetReps: config.repMin,
        reason: 'All working sets reached ${config.repMax} reps. Add weight.',
      );
    }

    if (stalledSessions(sessions) >= stallSessionsBeforeDeload && weight > 0) {
      return Recommendation(
        type: RecommendationType.deload,
        suggestedWeight: _deloadWeight(weight, config.weightStep),
        previousWeight: weight,
        repMin: config.repMin,
        repMax: config.repMax,
        targetReps: config.repMax,
        reason:
            'No progress for ${stalledSessions(sessions) + 1} sessions. '
            'Reduce the load ~10% and rebuild.',
      );
    }

    final atWeight = last.sets.where((s) => s.weight == weight);
    final lowest = atWeight.isEmpty
        ? config.repMin
        : atWeight.map((s) => s.reps).reduce((a, b) => a < b ? a : b);
    final target = (lowest + 1).clamp(config.repMin, config.repMax);
    return Recommendation(
      type: RecommendationType.addReps,
      suggestedWeight: weight,
      previousWeight: weight,
      repMin: config.repMin,
      repMax: config.repMax,
      targetReps: target,
      reason: 'Keep ${_fmt(weight)} kg and aim for $target+ reps per set.',
    );
  }

  /// Consecutive most-recent sessions that did not improve on the one before
  /// (same working weight and no more total reps).
  int stalledSessions(List<ExerciseSessionPerformance> history) {
    var count = 0;
    for (var i = 0; i < history.length - 1; i++) {
      final current = history[i];
      final previous = history[i + 1];
      final sameWeight = current.topWeight == previous.topWeight;
      final noMoreReps =
          current.totalRepsAtTopWeight <= previous.totalRepsAtTopWeight;
      if (sameWeight && noMoreReps) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  bool _reachedTopOfRange(
    ExerciseSessionPerformance last,
    ProgressionConfig config,
  ) {
    final weight = last.topWeight;
    final atWeight = last.sets.where((s) => s.weight == weight).toList();
    return atWeight.length >= config.workingSets &&
        atWeight.every((s) => s.reps >= config.repMax);
  }

  /// One step up, landing on the step grid: 30 → 31, and an off-grid
  /// 32.5 → 33 (never more than one step).
  double _increasedWeight(double weight, double step) {
    final next = roundDownToStep(weight + step, step);
    return next > weight ? next : _clean(weight + step);
  }

  double _deloadWeight(double weight, double step) {
    var reduced = roundDownToStep(weight * deloadFactor, step);
    if (reduced >= weight) reduced = weight - step;
    // A set needs a weight above 0: never suggest less than one step, and
    // keep the current weight when it is already at or below one step.
    if (reduced < step) reduced = weight > step ? step : weight;
    return _clean(reduced);
  }

  static double roundToStep(double value, double step) {
    if (step <= 0) return _clean(value);
    return _clean((value / step).round() * step);
  }

  static double roundDownToStep(double value, double step) {
    if (step <= 0) return _clean(value);
    // Small epsilon protects against 29.999999 floor errors.
    return _clean((value / step + 1e-9).floor() * step);
  }

  static double _clean(double v) => double.parse(v.toStringAsFixed(2));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
