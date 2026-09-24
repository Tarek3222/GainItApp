import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/training/volume_calculator.dart';

VolumeSetEntry entry(
  MuscleGroup muscle,
  DateTime at, {
  SessionStatus status = SessionStatus.completed,
  bool warmup = false,
}) => VolumeSetEntry(
  muscle: muscle,
  completedAt: at,
  sessionStatus: status,
  isWarmup: warmup,
);

void main() {
  final monday = DateTime(2026, 3, 2, 18);

  group('VolumeCalculator.directSets', () {
    test('counts working sets per muscle', () {
      final result = VolumeCalculator.directSets([
        entry(MuscleGroup.chest, monday),
        entry(MuscleGroup.chest, monday),
        entry(MuscleGroup.back, monday),
      ]);

      expect(result, {MuscleGroup.chest: 2, MuscleGroup.back: 1});
    });

    test('ignores warm-up sets', () {
      final result = VolumeCalculator.directSets([
        entry(MuscleGroup.chest, monday, warmup: true),
      ]);

      expect(result, isEmpty);
    });

    test('ignores abandoned and in-progress sessions', () {
      final result = VolumeCalculator.directSets([
        entry(MuscleGroup.chest, monday, status: SessionStatus.abandoned),
        entry(MuscleGroup.chest, monday, status: SessionStatus.inProgress),
      ]);

      expect(result, isEmpty);
    });

    test('includes the start boundary and excludes the end boundary', () {
      final from = DateTime(2026, 3, 1);
      final to = DateTime(2026, 3, 8);
      final result = VolumeCalculator.directSets(
        [
          entry(MuscleGroup.quads, from),
          entry(MuscleGroup.quads, to),
          entry(MuscleGroup.quads, from.subtract(const Duration(seconds: 1))),
        ],
        from: from,
        to: to,
      );

      expect(result, {MuscleGroup.quads: 1});
    });
  });

  test('plannedSets sums configured sets per muscle', () {
    final result = VolumeCalculator.plannedSets([
      (muscle: MuscleGroup.chest, sets: 3),
      (muscle: MuscleGroup.chest, sets: 2),
      (muscle: MuscleGroup.calves, sets: 4),
    ]);

    expect(result, {MuscleGroup.chest: 5, MuscleGroup.calves: 4});
  });
}
