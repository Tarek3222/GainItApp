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

  Exercise requireExercise(String id) =>
      exercise(id) ?? (throw NotFoundException('Exercise $id not found.'));

  /// Library order (by name). Archived exercises only with [includeArchived].
  List<Exercise> exercises({bool includeArchived = false}) =>
      _storage.exercises.values
          .where((e) => includeArchived || !e.isArchived)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  ProgramExercise requireProgramExercise(String id) =>
      _storage.programExercises.get(id) ??
      (throw NotFoundException('Exercise entry $id not found.'));

  /// Workout days of the active program that include [exerciseId]. Rest
  /// days keep their exercises but don't train them, so they're left out.
  List<WorkoutDay> daysUsing(String exerciseId) {
    final program = activeProgram();
    if (program == null) return const [];
    final dayIds = {
      for (final p in _storage.programExercises.values)
        if (p.exerciseId == exerciseId) p.workoutDayId,
    };
    return [
      for (final d in days(program.id))
        if (d.isWorkout && dayIds.contains(d.id)) d,
    ];
  }

  Future<void> saveExercise(Exercise exercise) async {
    ensureValid(Validators.exercise(exercise));
    final name = exercise.name.trim().toLowerCase();
    final clash = _storage.exercises.values.any(
      (e) =>
          e.id != exercise.id &&
          !e.isArchived &&
          e.name.trim().toLowerCase() == name,
    );
    if (clash) {
      throw const ValidationException([
        'An exercise with this name already exists.',
      ]);
    }
    await _storage.exercises.put(exercise.id, exercise);
  }

  /// Hides [exerciseId] from the library and takes it out of every day.
  /// The record itself stays so history and progress still resolve it.
  Future<void> archiveExercise(String exerciseId) async {
    final exercise = requireExercise(exerciseId);
    final affectedDays = {
      for (final p in _storage.programExercises.values)
        if (p.exerciseId == exerciseId) p.workoutDayId,
    };
    await _storage.programExercises.deleteAll([
      for (final p in _storage.programExercises.values)
        if (p.exerciseId == exerciseId) p.id,
    ]);
    for (final dayId in affectedDays) {
      await _writeOrder(_withoutLoneSupersets(programExercisesForDay(dayId)));
    }
    await _storage.exercises.put(
      exercise.id,
      exercise.copyWith(isArchived: true),
    );
  }

  /// Brings an archived exercise back to the library (not to any day).
  Future<void> restoreExercise(String exerciseId) async {
    final exercise = requireExercise(exerciseId);
    if (!exercise.isArchived) return;
    // saveExercise re-checks that no active exercise took the name meanwhile.
    await saveExercise(exercise.copyWith(isArchived: false));
  }

  Future<void> saveWorkoutDay(WorkoutDay day) async {
    requireDay(day.id);
    ensureValid(Validators.workoutDay(day));
    await _storage.workoutDays.put(day.id, day);
  }

  /// Adds or updates one exercise entry of a day.
  Future<void> saveProgramExercise(ProgramExercise entry) async {
    requireDay(entry.workoutDayId);
    final exercise = requireExercise(entry.exerciseId);
    if (exercise.isArchived) {
      throw const InvalidStateException('This exercise was removed.');
    }
    final duplicate = programExercisesForDay(
      entry.workoutDayId,
    ).any((p) => p.exerciseId == entry.exerciseId && p.id != entry.id);
    if (duplicate) {
      throw const InvalidStateException(
        'This exercise is already in the workout.',
      );
    }
    ensureValid(Validators.programExercise(entry));
    final others = [
      for (final p in programExercisesForDay(entry.workoutDayId))
        if (p.id != entry.id) p,
    ];
    final ordered = [...others]
      ..insert(entry.orderIndex.clamp(0, others.length), entry);
    await _writeOrder(_keepSupersetTogether(ordered, entry));
  }

  Future<void> removeProgramExercise(String id) async {
    final entry = requireProgramExercise(id);
    await _storage.programExercises.delete(id);
    await _writeOrder(
      _withoutLoneSupersets(programExercisesForDay(entry.workoutDayId)),
    );
  }

  /// Applies a new order to a day. [orderedIds] must list exactly the
  /// day's current entries.
  Future<void> reorderProgramExercises(
    String dayId,
    List<String> orderedIds,
  ) async {
    final current = programExercisesForDay(dayId);
    final currentIds = {for (final p in current) p.id};
    if (orderedIds.length != current.length ||
        !orderedIds.toSet().containsAll(currentIds)) {
      throw const InvalidStateException(
        'The exercise list changed. Please try again.',
      );
    }
    final byId = {for (final p in current) p.id: p};
    await _writeOrder(
      _withoutSplitSupersets([for (final id in orderedIds) byId[id]!]),
    );
  }

  /// Saves [ordered] with contiguous order indexes (0, 1, 2 …), writing
  /// only the entries that changed.
  Future<void> _writeOrder(List<ProgramExercise> ordered) async {
    final current = _storage.programExercises;
    final changed = <String, ProgramExercise>{};
    for (final (index, p) in ordered.indexed) {
      final next = p.orderIndex == index ? p : p.copyWith(orderIndex: index);
      if (current.get(next.id) != next) changed[next.id] = next;
    }
    if (changed.isNotEmpty) await current.putAll(changed);
  }

  // Superset rules: members of a group sit next to each other, and a group
  // needs at least two members once the day is edited.

  /// Moves [entry] next to the other members of its superset group.
  List<ProgramExercise> _keepSupersetTogether(
    List<ProgramExercise> ordered,
    ProgramExercise entry,
  ) {
    final group = entry.supersetGroup;
    if (group == null) return ordered;
    final list = [...ordered]..removeWhere((p) => p.id == entry.id);
    final lastMember = list.lastIndexWhere((p) => p.supersetGroup == group);
    if (lastMember == -1) return ordered;
    final firstMember = list.indexWhere((p) => p.supersetGroup == group);
    final wanted = ordered.indexWhere((p) => p.id == entry.id);
    // Already touching the group (just before, inside or just after it).
    if (wanted >= firstMember && wanted <= lastMember + 1) return ordered;
    return list..insert(lastMember + 1, entry);
  }

  /// Clears groups left with a single exercise (after a removal).
  List<ProgramExercise> _withoutLoneSupersets(List<ProgramExercise> ordered) {
    final counts = <int, int>{};
    for (final p in ordered) {
      final g = p.supersetGroup;
      if (g != null) counts[g] = (counts[g] ?? 0) + 1;
    }
    return [
      for (final p in ordered)
        if (p.supersetGroup != null && counts[p.supersetGroup] == 1)
          p.copyWith(clearSuperset: true)
        else
          p,
    ];
  }

  /// Clears groups whose members are no longer next to each other (after
  /// a reorder), then any group left alone.
  List<ProgramExercise> _withoutSplitSupersets(List<ProgramExercise> ordered) {
    final split = <int>{};
    for (final group in {for (final p in ordered) ?p.supersetGroup}) {
      final first = ordered.indexWhere((p) => p.supersetGroup == group);
      final last = ordered.lastIndexWhere((p) => p.supersetGroup == group);
      final contiguous = ordered
          .sublist(first, last + 1)
          .every((p) => p.supersetGroup == group);
      if (!contiguous) split.add(group);
    }
    return _withoutLoneSupersets([
      for (final p in ordered)
        if (split.contains(p.supersetGroup))
          p.copyWith(clearSuperset: true)
        else
          p,
    ]);
  }

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
