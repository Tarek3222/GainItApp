import 'package:equatable/equatable.dart';

/// Weight/reps of one working set, detached from storage.
class SetPerformance extends Equatable {
  const SetPerformance({required this.weight, required this.reps, this.rir});

  final double weight;
  final int reps;
  final int? rir;

  @override
  List<Object?> get props => [weight, reps, rir];
}

/// All working sets of one exercise within one completed session.
class ExerciseSessionPerformance extends Equatable {
  const ExerciseSessionPerformance({
    required this.sessionId,
    required this.date,
    required this.sets,
  });

  final String sessionId;
  final DateTime date;

  /// Working sets ordered by set number.
  final List<SetPerformance> sets;

  bool get isEmpty => sets.isEmpty;

  /// Heaviest load used; the "working weight" for double progression.
  double get topWeight =>
      sets.fold<double>(0, (max, s) => s.weight > max ? s.weight : max);

  int get totalReps => sets.fold<int>(0, (sum, s) => sum + s.reps);

  /// Reps performed at [topWeight].
  int get totalRepsAtTopWeight {
    final top = topWeight;
    return sets
        .where((s) => s.weight == top)
        .fold<int>(0, (sum, s) => sum + s.reps);
  }

  /// Most reps achieved in a single set.
  int get bestReps =>
      sets.fold<int>(0, (max, s) => s.reps > max ? s.reps : max);

  /// Sum of weight × reps.
  double get volumeLoad =>
      sets.fold<double>(0, (sum, s) => sum + s.weight * s.reps);

  @override
  List<Object?> get props => [sessionId, date, sets];
}
