import 'package:equatable/equatable.dart';

import 'enums.dart';

/// A complete training program ("what should happen").
class Program extends Equatable {
  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final DateTime startDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Program copyWith({DateTime? startDate, DateTime? updatedAt}) {
    return Program(
      id: id,
      name: name,
      description: description,
      isActive: isActive,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    isActive,
    startDate,
    createdAt,
    updatedAt,
  ];
}

/// One day of the weekly schedule.
class WorkoutDay extends Equatable {
  const WorkoutDay({
    required this.id,
    required this.programId,
    required this.weekday,
    required this.name,
    required this.type,
    required this.sortOrder,
  });

  final String id;
  final String programId;

  /// [DateTime.weekday]: 1 = Monday … 7 = Sunday.
  final int weekday;
  final String name;
  final DayType type;

  /// Display order; the GainIt week starts on Saturday (0).
  final int sortOrder;

  bool get isWorkout => type == DayType.workout;

  WorkoutDay copyWith({String? name, DayType? type}) => WorkoutDay(
    id: id,
    programId: programId,
    weekday: weekday,
    name: name ?? this.name,
    type: type ?? this.type,
    sortOrder: sortOrder,
  );

  @override
  List<Object?> get props => [id, programId, weekday, name, type, sortOrder];
}

/// Master exercise library entry.
class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.category,
    required this.createdAt,
    this.secondaryMuscles = const [],
    this.isCustom = false,
    this.instructions,
    this.imagePath,
    this.videoPath,
    this.isArchived = false,
    this.imagePaths = const [],
  });

  final String id;
  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final ExerciseCategory category;
  final bool isCustom;
  final DateTime createdAt;

  /// The user's own notes on how to perform the exercise.
  final String? instructions;

  /// Legacy single photo from before an exercise could have several. The
  /// v3 storage migration moves it into [imagePaths]; nothing writes it.
  final String? imagePath;

  /// Video file name in the app's media folder (see `MediaStore`).
  final String? videoPath;

  /// Photo file names in the app's media folder, in the order shown.
  final List<String> imagePaths;

  /// Hidden from the library and removed from the plan, but kept so past
  /// workouts and progress still find it.
  final bool isArchived;

  /// All photos in display order. Includes a legacy [imagePath] that was
  /// never migrated, so no photo is ever hidden or orphaned.
  List<String> get photos => [
    if (imagePath case final legacy? when !imagePaths.contains(legacy)) legacy,
    ...imagePaths,
  ];

  /// Every muscle the exercise trains, prime mover first.
  List<MuscleGroup> get targetMuscles => [primaryMuscle, ...secondaryMuscles];

  Exercise copyWith({
    String? name,
    MuscleGroup? primaryMuscle,
    List<MuscleGroup>? secondaryMuscles,
    ExerciseCategory? category,
    String? instructions,
    bool clearInstructions = false,
    List<String>? imagePaths,
    bool clearLegacyImage = false,
    String? videoPath,
    bool clearVideo = false,
    bool? isArchived,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      category: category ?? this.category,
      isCustom: isCustom,
      createdAt: createdAt,
      instructions: clearInstructions
          ? null
          : (instructions ?? this.instructions),
      imagePath: clearLegacyImage ? null : imagePath,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPath: clearVideo ? null : (videoPath ?? this.videoPath),
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    primaryMuscle,
    secondaryMuscles,
    category,
    isCustom,
    createdAt,
    instructions,
    imagePath,
    videoPath,
    isArchived,
    imagePaths,
  ];
}

/// How an exercise is configured inside a workout day. This is the
/// configuration the progression engine reads — never hard-coded in Dart.
class ProgramExercise extends Equatable {
  const ProgramExercise({
    required this.id,
    required this.workoutDayId,
    required this.exerciseId,
    required this.orderIndex,
    required this.workingSets,
    required this.repMin,
    required this.repMax,
    required this.restMinSeconds,
    required this.restMaxSeconds,
    required this.rirMin,
    required this.rirMax,
    required this.weightStep,
    this.progressionType = ProgressionType.doubleProgression,
    this.supersetGroup,
    this.notes,
  });

  final String id;
  final String workoutDayId;
  final String exerciseId;
  final int orderIndex;
  final int workingSets;
  final int repMin;
  final int repMax;
  final int restMinSeconds;
  final int restMaxSeconds;
  final int rirMin;
  final int rirMax;
  final ProgressionType progressionType;
  final double weightStep;

  /// Exercises sharing a group number are performed as a superset.
  final int? supersetGroup;
  final String? notes;

  ProgramExercise copyWith({
    int? orderIndex,
    int? workingSets,
    int? repMin,
    int? repMax,
    int? restMinSeconds,
    int? restMaxSeconds,
    int? rirMin,
    int? rirMax,
    double? weightStep,
    int? supersetGroup,
    bool clearSuperset = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return ProgramExercise(
      id: id,
      workoutDayId: workoutDayId,
      exerciseId: exerciseId,
      orderIndex: orderIndex ?? this.orderIndex,
      workingSets: workingSets ?? this.workingSets,
      repMin: repMin ?? this.repMin,
      repMax: repMax ?? this.repMax,
      restMinSeconds: restMinSeconds ?? this.restMinSeconds,
      restMaxSeconds: restMaxSeconds ?? this.restMaxSeconds,
      rirMin: rirMin ?? this.rirMin,
      rirMax: rirMax ?? this.rirMax,
      weightStep: weightStep ?? this.weightStep,
      progressionType: progressionType,
      supersetGroup: clearSuperset
          ? null
          : (supersetGroup ?? this.supersetGroup),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  List<Object?> get props => [
    id,
    workoutDayId,
    exerciseId,
    orderIndex,
    workingSets,
    repMin,
    repMax,
    restMinSeconds,
    restMaxSeconds,
    rirMin,
    rirMax,
    progressionType,
    weightStep,
    supersetGroup,
    notes,
  ];
}
