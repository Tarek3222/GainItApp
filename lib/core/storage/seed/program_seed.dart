import '../../domain/entities/enums.dart';
import '../../domain/entities/program.dart';

/// The initial hypertrophy program (spec §2), stored as data so the app never
/// hard-codes exercises, rep ranges or rest times in widgets or logic.
class ProgramSeedData {
  const ProgramSeedData({
    required this.program,
    required this.days,
    required this.exercises,
    required this.programExercises,
  });

  final Program program;
  final List<WorkoutDay> days;
  final List<Exercise> exercises;
  final List<ProgramExercise> programExercises;
}

abstract final class ProgramSeed {
  static const programId = 'program_hypertrophy_v1';

  static const sundayId = 'day_sun_chest_back_traps';
  static const mondayId = 'day_mon_legs';
  static const wednesdayId = 'day_wed_upper';
  static const thursdayId = 'day_thu_shoulders_arms';

  static ProgramSeedData build(DateTime now) {
    final exercises = <Exercise>[];
    final programExercises = <ProgramExercise>[];

    void add({
      required String dayId,
      required String id,
      required String name,
      required MuscleGroup primary,
      List<MuscleGroup> secondary = const [],
      required ExerciseCategory category,
      required int sets,
      required int repMin,
      required int repMax,
      required int restMin,
      int? restMax,
      double step = 1,
      int? superset,
      String? notes,
    }) {
      exercises.add(
        Exercise(
          id: 'ex_$id',
          name: name,
          primaryMuscle: primary,
          secondaryMuscles: secondary,
          category: category,
          createdAt: now,
        ),
      );
      final isCompound = category == ExerciseCategory.compound;
      programExercises.add(
        ProgramExercise(
          id: 'pe_$id',
          workoutDayId: dayId,
          exerciseId: 'ex_$id',
          orderIndex: programExercises
              .where((p) => p.workoutDayId == dayId)
              .length,
          workingSets: sets,
          repMin: repMin,
          repMax: repMax,
          restMinSeconds: restMin,
          restMaxSeconds: restMax ?? restMin,
          rirMin: isCompound ? 1 : 0,
          rirMax: isCompound ? 3 : 2,
          weightStep: step,
          supersetGroup: superset,
          notes: notes,
        ),
      );
    }

    const c = ExerciseCategory.compound;
    const i = ExerciseCategory.isolation;

    // Sunday — Chest + Back + Traps (19 sets). Chest/back alternate.
    add(
      dayId: sundayId,
      id: 'flat_barbell_bench',
      name: 'Flat Barbell Bench Press',
      primary: MuscleGroup.chest,
      secondary: [MuscleGroup.frontDelts, MuscleGroup.triceps],
      category: c,
      sets: 3,
      repMin: 6,
      repMax: 10,
      restMin: 120,
      restMax: 180,
    );
    add(
      dayId: sundayId,
      id: 'wide_barbell_row',
      name: 'Wide Barbell Row',
      primary: MuscleGroup.back,
      secondary: [MuscleGroup.rearDelts, MuscleGroup.biceps, MuscleGroup.traps],
      category: c,
      sets: 3,
      repMin: 6,
      repMax: 10,
      restMin: 120,
      restMax: 180,
    );
    add(
      dayId: sundayId,
      id: 'incline_bench_press',
      name: 'Incline Bench Press',
      primary: MuscleGroup.chest,
      secondary: [MuscleGroup.frontDelts, MuscleGroup.triceps],
      category: c,
      sets: 3,
      repMin: 8,
      repMax: 12,
      restMin: 120,
    );
    add(
      dayId: sundayId,
      id: 'lat_pulldown',
      name: 'Lat Pulldown',
      primary: MuscleGroup.back,
      secondary: [MuscleGroup.biceps],
      category: c,
      sets: 3,
      repMin: 8,
      repMax: 12,
      restMin: 120,
    );
    add(
      dayId: sundayId,
      id: 'pec_fly',
      name: 'Pec Fly',
      primary: MuscleGroup.chest,
      category: i,
      sets: 2,
      repMin: 12,
      repMax: 15,
      restMin: 60,
      restMax: 90,
    );
    add(
      dayId: sundayId,
      id: 'seated_cable_row',
      name: 'Seated Cable Row',
      primary: MuscleGroup.back,
      secondary: [MuscleGroup.rearDelts, MuscleGroup.biceps],
      category: c,
      sets: 2,
      repMin: 10,
      repMax: 12,
      restMin: 90,
    );
    add(
      dayId: sundayId,
      id: 'dumbbell_shrug',
      name: 'Dumbbell Shrugs',
      primary: MuscleGroup.traps,
      secondary: [MuscleGroup.forearms],
      category: i,
      sets: 3,
      repMin: 10,
      repMax: 15,
      restMin: 60,
      restMax: 90,
    );

    // Monday — Legs (20 sets).
    add(
      dayId: mondayId,
      id: 'squat',
      name: 'Squat / Hack Squat',
      primary: MuscleGroup.quads,
      secondary: [MuscleGroup.glutes],
      category: c,
      sets: 4,
      repMin: 6,
      repMax: 10,
      restMin: 180,
    );
    add(
      dayId: mondayId,
      id: 'lying_leg_curl',
      name: 'Lying Leg Curl',
      primary: MuscleGroup.hamstrings,
      category: i,
      sets: 4,
      repMin: 10,
      repMax: 15,
      restMin: 90,
    );
    add(
      dayId: mondayId,
      id: 'leg_press',
      name: 'Leg Press',
      primary: MuscleGroup.quads,
      secondary: [MuscleGroup.glutes],
      category: c,
      sets: 3,
      repMin: 10,
      repMax: 15,
      restMin: 120,
    );
    add(
      dayId: mondayId,
      id: 'back_extension_45',
      name: '45° Back Extension',
      primary: MuscleGroup.hamstrings,
      secondary: [MuscleGroup.glutes, MuscleGroup.lowerBack],
      category: c,
      sets: 3,
      repMin: 10,
      repMax: 15,
      restMin: 90,
      notes: 'Option: try a light dumbbell RDL after 4–6 weeks.',
    );
    add(
      dayId: mondayId,
      id: 'leg_extension',
      name: 'Leg Extension',
      primary: MuscleGroup.quads,
      category: i,
      sets: 2,
      repMin: 12,
      repMax: 15,
      restMin: 90,
    );
    add(
      dayId: mondayId,
      id: 'standing_calf_raise',
      name: 'Standing Calf Raise',
      primary: MuscleGroup.calves,
      category: i,
      sets: 4,
      repMin: 10,
      repMax: 15,
      restMin: 60,
      restMax: 90,
    );

    // Wednesday — Upper + Side Delts + Forearms (18 sets).
    add(
      dayId: wednesdayId,
      id: 'flat_dumbbell_bench',
      name: 'Flat Dumbbell Bench Press',
      primary: MuscleGroup.chest,
      secondary: [MuscleGroup.frontDelts, MuscleGroup.triceps],
      category: c,
      sets: 3,
      repMin: 8,
      repMax: 12,
      restMin: 120,
    );
    add(
      dayId: wednesdayId,
      id: 'high_cable_pulldown',
      name: 'High Cable Pulldown',
      primary: MuscleGroup.back,
      secondary: [MuscleGroup.biceps],
      category: c,
      sets: 3,
      repMin: 10,
      repMax: 12,
      restMin: 120,
    );
    add(
      dayId: wednesdayId,
      id: 'cable_fly',
      name: 'Cable Fly',
      primary: MuscleGroup.chest,
      category: i,
      sets: 2,
      repMin: 12,
      repMax: 15,
      restMin: 60,
      restMax: 90,
    );
    add(
      dayId: wednesdayId,
      id: 'row_width',
      name: 'Row / Width Exercise',
      primary: MuscleGroup.back,
      secondary: [MuscleGroup.rearDelts, MuscleGroup.biceps],
      category: c,
      sets: 2,
      repMin: 10,
      repMax: 12,
      restMin: 90,
    );
    add(
      dayId: wednesdayId,
      id: 'cable_lateral_raise',
      name: 'Cable Lateral Raise',
      primary: MuscleGroup.sideDelts,
      category: i,
      sets: 4,
      repMin: 12,
      repMax: 20,
      restMin: 60,
    );
    add(
      dayId: wednesdayId,
      id: 'wrist_curl',
      name: 'Wrist Curl',
      primary: MuscleGroup.forearms,
      category: i,
      sets: 2,
      repMin: 15,
      repMax: 20,
      restMin: 60,
    );
    add(
      dayId: wednesdayId,
      id: 'reverse_wrist_curl',
      name: 'Reverse Wrist Curl',
      primary: MuscleGroup.forearms,
      category: i,
      sets: 2,
      repMin: 15,
      repMax: 20,
      restMin: 60,
    );

    // Thursday — Shoulders + Arms (22 sets). Biceps/triceps supersets.
    add(
      dayId: thursdayId,
      id: 'dumbbell_lateral_raise',
      name: 'Dumbbell Lateral Raise',
      primary: MuscleGroup.sideDelts,
      category: i,
      sets: 4,
      repMin: 12,
      repMax: 20,
      restMin: 60,
    );
    add(
      dayId: thursdayId,
      id: 'cable_rear_delt_rope',
      name: 'Cable Rear-Delt Rope',
      primary: MuscleGroup.rearDelts,
      category: i,
      sets: 3,
      repMin: 12,
      repMax: 20,
      restMin: 60,
    );
    add(
      dayId: thursdayId,
      id: 'machine_front_raise',
      name: 'Machine Front Raise',
      primary: MuscleGroup.frontDelts,
      category: i,
      sets: 3,
      repMin: 8,
      repMax: 12,
      restMin: 120,
    );
    add(
      dayId: thursdayId,
      id: 'overhead_triceps_extension',
      name: 'Overhead Triceps Extension',
      primary: MuscleGroup.triceps,
      category: i,
      sets: 3,
      repMin: 8,
      repMax: 12,
      restMin: 0,
      superset: 1,
      notes: 'Superset with Incline Dumbbell Curl.',
    );
    add(
      dayId: thursdayId,
      id: 'incline_dumbbell_curl',
      name: 'Incline Dumbbell Curl',
      primary: MuscleGroup.biceps,
      category: i,
      sets: 3,
      repMin: 8,
      repMax: 12,
      restMin: 90,
      superset: 1,
    );
    add(
      dayId: thursdayId,
      id: 'straight_bar_pushdown',
      name: 'Straight-Bar Triceps Pushdown',
      primary: MuscleGroup.triceps,
      category: i,
      sets: 3,
      repMin: 10,
      repMax: 15,
      restMin: 0,
      superset: 2,
      notes: 'Superset with Hammer Curl.',
    );
    add(
      dayId: thursdayId,
      id: 'hammer_curl',
      name: 'Hammer Curl',
      primary: MuscleGroup.biceps,
      secondary: [MuscleGroup.forearms],
      category: i,
      sets: 3,
      repMin: 10,
      repMax: 12,
      restMin: 90,
      superset: 2,
    );

    WorkoutDay day(String id, int weekday, String name, DayType type) =>
        WorkoutDay(
          id: id,
          programId: programId,
          weekday: weekday,
          name: name,
          type: type,
          sortOrder: (weekday - DateTime.saturday) % 7,
        );

    return ProgramSeedData(
      program: Program(
        id: programId,
        name: 'Hypertrophy',
        description:
            '4-day hypertrophy split with double progression. Keep 1–3 RIR '
            'on compounds and 0–2 RIR on the final isolation set. '
            'Warm-up sets are not counted.',
        isActive: true,
        startDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
        updatedAt: now,
      ),
      days: [
        day('day_sat_rest', DateTime.saturday, 'Rest', DayType.rest),
        day(sundayId, DateTime.sunday, 'Chest + Back + Traps', DayType.workout),
        day(mondayId, DateTime.monday, 'Legs', DayType.workout),
        day('day_tue_rest', DateTime.tuesday, 'Rest', DayType.rest),
        day(
          wednesdayId,
          DateTime.wednesday,
          'Upper + Side Delts + Forearms',
          DayType.workout,
        ),
        day(thursdayId, DateTime.thursday, 'Shoulders + Arms', DayType.workout),
        day('day_fri_rest', DateTime.friday, 'Rest', DayType.rest),
      ],
      exercises: exercises,
      programExercises: programExercises,
    );
  }
}
