import 'package:equatable/equatable.dart';

import '../entities/body_weight_entry.dart';

class WeightPoint extends Equatable {
  const WeightPoint(this.date, this.weightKg);

  final DateTime date;
  final double weightKg;

  @override
  List<Object?> get props => [date, weightKg];
}

class BodyWeightSummary extends Equatable {
  const BodyWeightSummary({
    required this.latest,
    required this.changeOverPeriod,
    required this.periodDays,
  });

  final BodyWeightEntry latest;

  /// Difference between the latest weigh-in and the closest one at or before
  /// the start of the period; `null` when there is no older entry.
  final double? changeOverPeriod;
  final int periodDays;

  @override
  List<Object?> get props => [latest, changeOverPeriod, periodDays];
}

/// Body-weight analytics. Uses rolling averages rather than reacting to a
/// single weigh-in (spec §29).
abstract final class BodyWeightTrend {
  static List<BodyWeightEntry> sortedAscending(List<BodyWeightEntry> entries) =>
      [...entries]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  static BodyWeightSummary? summary(
    List<BodyWeightEntry> entries, {
    int periodDays = 14,
  }) {
    if (entries.isEmpty) return null;
    final sorted = sortedAscending(entries);
    final latest = sorted.last;
    final cutoff = latest.measuredAt.subtract(Duration(days: periodDays));
    BodyWeightEntry? baseline;
    for (final entry in sorted) {
      if (entry.measuredAt.isAfter(cutoff)) break;
      baseline = entry;
    }
    baseline ??= sorted.length > 1 ? sorted.first : null;
    final change = baseline == null
        ? null
        : double.parse(
            (latest.weightKg - baseline.weightKg).toStringAsFixed(1),
          );
    return BodyWeightSummary(
      latest: latest,
      changeOverPeriod: change,
      periodDays: periodDays,
    );
  }

  /// Trailing average over [windowDays] calendar days for each entry.
  static List<WeightPoint> rollingAverage(
    List<BodyWeightEntry> entries, {
    int windowDays = 7,
  }) {
    final sorted = sortedAscending(entries);
    final points = <WeightPoint>[];
    for (var i = 0; i < sorted.length; i++) {
      final end = sorted[i].measuredAt;
      final start = end.subtract(Duration(days: windowDays));
      final window = sorted
          .sublist(0, i + 1)
          .where((e) => e.measuredAt.isAfter(start));
      final avg =
          window.fold<double>(0, (sum, e) => sum + e.weightKg) / window.length;
      points.add(WeightPoint(end, double.parse(avg.toStringAsFixed(2))));
    }
    return points;
  }
}
