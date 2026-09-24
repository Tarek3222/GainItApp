import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/training/volume_calculator.dart';
import 'package:gainit/core/storage/local_data_sources/program_local_data_source.dart';
import 'package:gainit/core/storage/seed/program_seed.dart';

import '../../helpers/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late ProgramLocalDataSource programs;

  setUp(() async {
    await harness.setUp();
    programs = ProgramLocalDataSource(harness.storage);
    await programs.seedIfEmpty(DateTime(2026, 3, 1));
  });
  tearDown(harness.tearDown);

  test('seeds a 7-day week with 4 workouts', () {
    final days = programs.days(ProgramSeed.programId);

    expect(days, hasLength(7));
    expect(days.first.weekday, DateTime.saturday);
    expect(days.where((d) => d.isWorkout), hasLength(4));
  });

  test('seeded workout days have the spec working-set totals', () {
    int total(String dayId) => programs
        .programExercisesForDay(dayId)
        .fold(0, (sum, p) => sum + p.workingSets);

    expect(total(ProgramSeed.sundayId), 19);
    expect(total(ProgramSeed.mondayId), 20);
    expect(total(ProgramSeed.wednesdayId), 18);
    expect(total(ProgramSeed.thursdayId), 22);
  });

  test('exercise→muscle mapping reproduces the spec weekly volume', () {
    final program = programs.requireActiveProgram();
    final config = [
      for (final day in programs.days(program.id))
        for (final pe in programs.programExercisesForDay(day.id))
          (
            muscle: programs.exercise(pe.exerciseId)!.primaryMuscle,
            sets: pe.workingSets,
          ),
    ];

    final volume = VolumeCalculator.plannedSets(config);

    expect(volume[MuscleGroup.chest], 13);
    expect(volume[MuscleGroup.back], 13);
    expect(volume[MuscleGroup.quads], 9);
    expect(volume[MuscleGroup.hamstrings], 7);
    expect(volume[MuscleGroup.calves], 4);
    expect(volume[MuscleGroup.sideDelts], 8);
    expect(volume[MuscleGroup.rearDelts], 3);
    expect(volume[MuscleGroup.biceps], 6);
    expect(volume[MuscleGroup.triceps], 6);
    expect(volume[MuscleGroup.traps], 3);
    expect(volume[MuscleGroup.forearms], 4);
  });

  test('seeding twice does not duplicate data', () async {
    await programs.seedIfEmpty(DateTime(2026, 3, 1));

    expect(harness.storage.programs.length, 1);
    expect(harness.storage.programExercises.length, 27);
  });

  test('compounds target 1–3 RIR and isolations 0–2 RIR', () {
    final bench = harness.storage.programExercises.get(
      'pe_flat_barbell_bench',
    )!;
    final fly = harness.storage.programExercises.get('pe_pec_fly')!;

    expect((bench.rirMin, bench.rirMax), (1, 3));
    expect((fly.rirMin, fly.rirMax), (0, 2));
  });
}
