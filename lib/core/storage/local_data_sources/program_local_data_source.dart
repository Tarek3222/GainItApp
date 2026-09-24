import '../../domain/entities/program.dart';
import '../../domain/validation/validators.dart';
import '../../errors/exceptions.dart';
import '../hive_storage.dart';
import '../seed/program_seed.dart';
import '../storage_guard.dart';

/// Program configuration: programs, weekly days, exercises and their targets.
class ProgramLocalDataSource {
  const ProgramLocalDataSource(this._storage);

  final HiveStorage _storage;

  Program? activeProgram() {
    for (final program in _storage.programs.values) {
      if (program.isActive) return program;
    }
    return null;
  }

  Program requireActiveProgram() =>
      activeProgram() ?? (throw const NotFoundException('No active program.'));

  Future<void> saveProgram(Program program) async {
    ensureValid(Validators.program(program));
    await _storage.programs.put(program.id, program);
  }

  List<WorkoutDay> days(String programId) =>
      _storage.workoutDays.values
          .where((d) => d.programId == programId)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  WorkoutDay requireDay(String dayId) =>
      _storage.workoutDays.get(dayId) ??
      (throw NotFoundException('Workout day $dayId not found.'));

  Exercise? exercise(String id) => _storage.exercises.get(id);

  List<Exercise> exercises() =>
      _storage.exercises.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<ProgramExercise> programExercisesForDay(String dayId) =>
      _storage.programExercises.values
          .where((p) => p.workoutDayId == dayId)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  List<ChangeTrigger> get triggers => [
    _storage.programs.watch,
    _storage.workoutDays.watch,
    _storage.programExercises.watch,
    _storage.exercises.watch,
  ];

  Stream<T> watch<T>(T Function() query) => watchTriggers(triggers, query);

  /// Writes the seed program once: children first (exercises, days,
  /// program exercises), each box in a single `putAll`, and the program
  /// record last. If the app crashes mid-seed, seeding runs again on the next
  /// launch because the program record is still missing.
  Future<void> seedIfEmpty(DateTime now) async {
    if (_storage.programs.isNotEmpty) return;
    final seed = ProgramSeed.build(now);
    for (final pe in seed.programExercises) {
      ensureValid(Validators.programExercise(pe));
    }
    await _storage.exercises.putAll({for (final e in seed.exercises) e.id: e});
    await _storage.workoutDays.putAll({for (final d in seed.days) d.id: d});
    await _storage.programExercises.putAll({
      for (final p in seed.programExercises) p.id: p,
    });
    await _storage.programs.put(seed.program.id, seed.program);
  }
}
