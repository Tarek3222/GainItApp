import 'package:equatable/equatable.dart';

import '../entities/enums.dart';
import '../units/unit_converter.dart';
import 'performance.dart';

/// Exercise configuration the engine needs — read from stored program data,
/// never from `if (exercise == bench)` conditions.
class ProgressionConfig extends Equatable {
  const ProgressionConfig({
    required this.workingSets,
    required this.repMin,
    required this.repMax,
    required this.weightStep,
    this.unitSystem = UnitSystem.metric,
  });

  final int workingSets;
  final int repMin;
  final int repMax;

  /// Load increment in kg.
  final double weightStep;

  /// The unit the user loads the bar in. Imperial progression runs on a
  /// whole-pound grid so suggestions are loads the user can actually pick.
  final UnitSystem unitSystem;

  @override
  List<Object?> get props => [
    workingSets,
    repMin,
    repMax,
    weightStep,
    unitSystem,
  ];
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
    this.suggestedWeight,
    this.previousWeight,
    this.targetReps,
    this.sessionsWithoutProgress = 0,
  });

  final RecommendationType type;

  /// `null` when there is no history to base a load on.
  final double? suggestedWeight;
  final double? previousWeight;
  final int repMin;
  final int repMax;

  /// Reps to aim for on each set this session.
  final int? targetReps;

  /// Sessions in a row without progress; set for a deload.
  final int sessionsWithoutProgress;

  @override
  List<Object?> get props => [
    type,
    suggestedWeight,
    previousWeight,
    repMin,
    repMax,
    targetReps,
    sessionsWithoutProgress,
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
    if (config.unitSystem == UnitSystem.imperial) {
      return _recommendInPounds(config, history);
    }
    return _recommend(config, history);
  }

  /// Runs the same rules on pound values with a whole-pound step (1 kg ≈
  /// 2 lb), then converts the suggested loads back to kg for storage.
  Recommendation _recommendInPounds(
    ProgressionConfig config,
    List<ExerciseSessionPerformance> history,
  ) {
    double toLb(double kg) => _clean(UnitConverter.kgToLb(kg));
    final stepLb = UnitConverter.kgToLb(config.weightStep).roundToDouble();
    final inPounds = _recommend(
      ProgressionConfig(
        workingSets: config.workingSets,
        repMin: config.repMin,
        repMax: config.repMax,
        weightStep: stepLb < 1 ? 1 : stepLb,
      ),
      [
        for (final session in history)
          ExerciseSessionPerformance(
            sessionId: session.sessionId,
            date: session.date,
            sets: [
              for (final set in session.sets)
                SetPerformance(
                  weight: toLb(set.weight),
                  reps: set.reps,
                  rir: set.rir,
                ),
            ],
          ),
      ],
    );
    double? toKg(double? lb) => lb == null ? null : UnitConverter.lbToKg(lb);
    return Recommendation(
      type: inPounds.type,
      suggestedWeight: toKg(inPounds.suggestedWeight),
      previousWeight: toKg(inPounds.previousWeight),
      repMin: inPounds.repMin,
      repMax: inPounds.repMax,
      targetReps: inPounds.targetReps,
      sessionsWithoutProgress: inPounds.sessionsWithoutProgress,
    );
  }

  Recommendation _recommend(
    ProgressionConfig config,
    List<ExerciseSessionPerformance> history,
  ) {
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
        sessionsWithoutProgress: stalledSessions(sessions) + 1,
      );
    }

    final atWeight = last.sets.where((s) => sameWeight(s.weight, weight));
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
    );
  }

  /// Consecutive most-recent sessions that did not improve on the one before
  /// (same working weight and no more total reps).
  int stalledSessions(List<ExerciseSessionPerformance> history) {
    var count = 0;
    for (var i = 0; i < history.length - 1; i++) {
      final current = history[i];
      final previous = history[i + 1];
      final sameLoad = sameWeight(current.topWeight, previous.topWeight);
      final noMoreReps =
          current.totalRepsAtTopWeight <= previous.totalRepsAtTopWeight;
      if (sameLoad && noMoreReps) {
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
    final atWeight = last.sets
        .where((s) => sameWeight(s.weight, weight))
        .toList();
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

  /// Loads within 0.01 are the same bar; unit conversion leaves tiny
  /// floating-point differences that must not count as a weight change.
  static bool sameWeight(double a, double b) => (a - b).abs() < weightTolerance;

  static const weightTolerance = 0.01;
}
