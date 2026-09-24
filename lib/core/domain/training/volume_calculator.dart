import 'package:equatable/equatable.dart';

import '../entities/enums.dart';

/// A logged set reduced to what volume calculation needs.
class VolumeSetEntry extends Equatable {
  const VolumeSetEntry({
    required this.muscle,
    required this.completedAt,
    required this.sessionStatus,
    this.isWarmup = false,
  });

  final MuscleGroup muscle;
  final DateTime completedAt;
  final SessionStatus sessionStatus;
  final bool isWarmup;

  @override
  List<Object?> get props => [muscle, completedAt, sessionStatus, isWarmup];
}

/// Direct-set volume per muscle, calculated from actual records (spec §13).
abstract final class VolumeCalculator {
  /// Counts working sets of completed sessions within `[from, to)`.
  /// Warm-ups and abandoned / in-progress sessions never count.
  static Map<MuscleGroup, int> directSets(
    Iterable<VolumeSetEntry> sets, {
    DateTime? from,
    DateTime? to,
  }) {
    final result = <MuscleGroup, int>{};
    for (final set in sets) {
      if (set.isWarmup) continue;
      if (set.sessionStatus != SessionStatus.completed) continue;
      if (from != null && set.completedAt.isBefore(from)) continue;
      if (to != null && !set.completedAt.isBefore(to)) continue;
      result.update(set.muscle, (v) => v + 1, ifAbsent: () => 1);
    }
    return _sorted(result);
  }

  /// Planned weekly volume from program configuration.
  static Map<MuscleGroup, int> plannedSets(
    Iterable<({MuscleGroup muscle, int sets})> configuration,
  ) {
    final result = <MuscleGroup, int>{};
    for (final item in configuration) {
      result.update(
        item.muscle,
        (v) => v + item.sets,
        ifAbsent: () => item.sets,
      );
    }
    return _sorted(result);
  }

  static Map<MuscleGroup, int> _sorted(Map<MuscleGroup, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return Map.fromEntries(entries);
  }
}
