// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final typeId = 1;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      heightCm: (fields[2] as num).toDouble(),
      goal: fields[3] as TrainingGoal,
      trainingStartDate: fields[4] as DateTime,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
      unitSystem: fields[5] == null
          ? UnitSystem.metric
          : fields[5] as UnitSystem,
      birthDate: fields[8] as DateTime?,
      photoPath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.heightCm)
      ..writeByte(3)
      ..write(obj.goal)
      ..writeByte(4)
      ..write(obj.trainingStartDate)
      ..writeByte(5)
      ..write(obj.unitSystem)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.birthDate)
      ..writeByte(9)
      ..write(obj.photoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProgramAdapter extends TypeAdapter<Program> {
  @override
  final typeId = 2;

  @override
  Program read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Program(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      isActive: fields[3] as bool,
      startDate: fields[4] as DateTime,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Program obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutDayAdapter extends TypeAdapter<WorkoutDay> {
  @override
  final typeId = 3;

  @override
  WorkoutDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutDay(
      id: fields[0] as String,
      programId: fields[1] as String,
      weekday: (fields[2] as num).toInt(),
      name: fields[3] as String,
      type: fields[4] as DayType,
      sortOrder: (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutDay obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.programId)
      ..writeByte(2)
      ..write(obj.weekday)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final typeId = 4;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      id: fields[0] as String,
      name: fields[1] as String,
      primaryMuscle: fields[2] as MuscleGroup,
      category: fields[4] as ExerciseCategory,
      createdAt: fields[6] as DateTime,
      secondaryMuscles: fields[3] == null
          ? const []
          : (fields[3] as List).cast<MuscleGroup>(),
      isCustom: fields[5] == null ? false : fields[5] as bool,
      instructions: fields[7] as String?,
      imagePath: fields[8] as String?,
      videoPath: fields[9] as String?,
      isArchived: fields[10] == null ? false : fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.primaryMuscle)
      ..writeByte(3)
      ..write(obj.secondaryMuscles)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.isCustom)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.instructions)
      ..writeByte(8)
      ..write(obj.imagePath)
      ..writeByte(9)
      ..write(obj.videoPath)
      ..writeByte(10)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProgramExerciseAdapter extends TypeAdapter<ProgramExercise> {
  @override
  final typeId = 5;

  @override
  ProgramExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramExercise(
      id: fields[0] as String,
      workoutDayId: fields[1] as String,
      exerciseId: fields[2] as String,
      orderIndex: (fields[3] as num).toInt(),
      workingSets: (fields[4] as num).toInt(),
      repMin: (fields[5] as num).toInt(),
      repMax: (fields[6] as num).toInt(),
      restMinSeconds: (fields[7] as num).toInt(),
      restMaxSeconds: (fields[8] as num).toInt(),
      rirMin: (fields[9] as num).toInt(),
      rirMax: (fields[10] as num).toInt(),
      weightStep: (fields[12] as num).toDouble(),
      progressionType: fields[11] == null
          ? ProgressionType.doubleProgression
          : fields[11] as ProgressionType,
      supersetGroup: (fields[13] as num?)?.toInt(),
      notes: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramExercise obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workoutDayId)
      ..writeByte(2)
      ..write(obj.exerciseId)
      ..writeByte(3)
      ..write(obj.orderIndex)
      ..writeByte(4)
      ..write(obj.workingSets)
      ..writeByte(5)
      ..write(obj.repMin)
      ..writeByte(6)
      ..write(obj.repMax)
      ..writeByte(7)
      ..write(obj.restMinSeconds)
      ..writeByte(8)
      ..write(obj.restMaxSeconds)
      ..writeByte(9)
      ..write(obj.rirMin)
      ..writeByte(10)
      ..write(obj.rirMax)
      ..writeByte(11)
      ..write(obj.progressionType)
      ..writeByte(12)
      ..write(obj.weightStep)
      ..writeByte(13)
      ..write(obj.supersetGroup)
      ..writeByte(14)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final typeId = 6;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession(
      id: fields[0] as String,
      programId: fields[1] as String,
      workoutDayId: fields[2] as String,
      workoutName: fields[3] as String,
      startedAt: fields[4] as DateTime,
      status: fields[6] as SessionStatus,
      completedAt: fields[5] as DateTime?,
      notes: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.programId)
      ..writeByte(2)
      ..write(obj.workoutDayId)
      ..writeByte(3)
      ..write(obj.workoutName)
      ..writeByte(4)
      ..write(obj.startedAt)
      ..writeByte(5)
      ..write(obj.completedAt)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionExerciseAdapter extends TypeAdapter<SessionExercise> {
  @override
  final typeId = 7;

  @override
  SessionExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionExercise(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      programExerciseId: fields[2] as String,
      exerciseId: fields[3] as String,
      exerciseName: fields[4] as String,
      primaryMuscle: fields[5] as MuscleGroup,
      category: fields[6] as ExerciseCategory,
      orderIndex: (fields[7] as num).toInt(),
      targetSets: (fields[8] as num).toInt(),
      repMin: (fields[9] as num).toInt(),
      repMax: (fields[10] as num).toInt(),
      restSeconds: (fields[11] as num).toInt(),
      rirMin: (fields[12] as num).toInt(),
      rirMax: (fields[13] as num).toInt(),
      weightStep: (fields[14] as num).toDouble(),
      supersetGroup: (fields[15] as num?)?.toInt(),
      isSkipped: fields[16] == null ? false : fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SessionExercise obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.programExerciseId)
      ..writeByte(3)
      ..write(obj.exerciseId)
      ..writeByte(4)
      ..write(obj.exerciseName)
      ..writeByte(5)
      ..write(obj.primaryMuscle)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.orderIndex)
      ..writeByte(8)
      ..write(obj.targetSets)
      ..writeByte(9)
      ..write(obj.repMin)
      ..writeByte(10)
      ..write(obj.repMax)
      ..writeByte(11)
      ..write(obj.restSeconds)
      ..writeByte(12)
      ..write(obj.rirMin)
      ..writeByte(13)
      ..write(obj.rirMax)
      ..writeByte(14)
      ..write(obj.weightStep)
      ..writeByte(15)
      ..write(obj.supersetGroup)
      ..writeByte(16)
      ..write(obj.isSkipped);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SetLogAdapter extends TypeAdapter<SetLog> {
  @override
  final typeId = 8;

  @override
  SetLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetLog(
      id: fields[0] as String,
      sessionExerciseId: fields[1] as String,
      setNumber: (fields[2] as num).toInt(),
      plannedRepsMin: (fields[3] as num).toInt(),
      plannedRepsMax: (fields[4] as num).toInt(),
      actualWeight: (fields[6] as num).toDouble(),
      actualReps: (fields[7] as num).toInt(),
      completedAt: fields[9] as DateTime,
      plannedWeight: (fields[5] as num?)?.toDouble(),
      rir: (fields[8] as num?)?.toInt(),
      isWarmup: fields[10] == null ? false : fields[10] as bool,
      notes: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SetLog obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionExerciseId)
      ..writeByte(2)
      ..write(obj.setNumber)
      ..writeByte(3)
      ..write(obj.plannedRepsMin)
      ..writeByte(4)
      ..write(obj.plannedRepsMax)
      ..writeByte(5)
      ..write(obj.plannedWeight)
      ..writeByte(6)
      ..write(obj.actualWeight)
      ..writeByte(7)
      ..write(obj.actualReps)
      ..writeByte(8)
      ..write(obj.rir)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.isWarmup)
      ..writeByte(11)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BodyWeightEntryAdapter extends TypeAdapter<BodyWeightEntry> {
  @override
  final typeId = 9;

  @override
  BodyWeightEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyWeightEntry(
      id: fields[0] as String,
      weightKg: (fields[1] as num).toDouble(),
      measuredAt: fields[2] as DateTime,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BodyWeightEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weightKg)
      ..writeByte(2)
      ..write(obj.measuredAt)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyWeightEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MuscleGroupAdapter extends TypeAdapter<MuscleGroup> {
  @override
  final typeId = 10;

  @override
  MuscleGroup read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MuscleGroup.chest;
      case 1:
        return MuscleGroup.back;
      case 2:
        return MuscleGroup.traps;
      case 3:
        return MuscleGroup.frontDelts;
      case 4:
        return MuscleGroup.sideDelts;
      case 5:
        return MuscleGroup.rearDelts;
      case 6:
        return MuscleGroup.biceps;
      case 7:
        return MuscleGroup.triceps;
      case 8:
        return MuscleGroup.forearms;
      case 9:
        return MuscleGroup.quads;
      case 10:
        return MuscleGroup.hamstrings;
      case 11:
        return MuscleGroup.glutes;
      case 12:
        return MuscleGroup.calves;
      case 13:
        return MuscleGroup.lowerBack;
      case 14:
        return MuscleGroup.abs;
      default:
        return MuscleGroup.chest;
    }
  }

  @override
  void write(BinaryWriter writer, MuscleGroup obj) {
    switch (obj) {
      case MuscleGroup.chest:
        writer.writeByte(0);
      case MuscleGroup.back:
        writer.writeByte(1);
      case MuscleGroup.traps:
        writer.writeByte(2);
      case MuscleGroup.frontDelts:
        writer.writeByte(3);
      case MuscleGroup.sideDelts:
        writer.writeByte(4);
      case MuscleGroup.rearDelts:
        writer.writeByte(5);
      case MuscleGroup.biceps:
        writer.writeByte(6);
      case MuscleGroup.triceps:
        writer.writeByte(7);
      case MuscleGroup.forearms:
        writer.writeByte(8);
      case MuscleGroup.quads:
        writer.writeByte(9);
      case MuscleGroup.hamstrings:
        writer.writeByte(10);
      case MuscleGroup.glutes:
        writer.writeByte(11);
      case MuscleGroup.calves:
        writer.writeByte(12);
      case MuscleGroup.lowerBack:
        writer.writeByte(13);
      case MuscleGroup.abs:
        writer.writeByte(14);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuscleGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseCategoryAdapter extends TypeAdapter<ExerciseCategory> {
  @override
  final typeId = 11;

  @override
  ExerciseCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExerciseCategory.compound;
      case 1:
        return ExerciseCategory.isolation;
      default:
        return ExerciseCategory.compound;
    }
  }

  @override
  void write(BinaryWriter writer, ExerciseCategory obj) {
    switch (obj) {
      case ExerciseCategory.compound:
        writer.writeByte(0);
      case ExerciseCategory.isolation:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayTypeAdapter extends TypeAdapter<DayType> {
  @override
  final typeId = 12;

  @override
  DayType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DayType.workout;
      case 1:
        return DayType.rest;
      default:
        return DayType.workout;
    }
  }

  @override
  void write(BinaryWriter writer, DayType obj) {
    switch (obj) {
      case DayType.workout:
        writer.writeByte(0);
      case DayType.rest:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionStatusAdapter extends TypeAdapter<SessionStatus> {
  @override
  final typeId = 13;

  @override
  SessionStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SessionStatus.inProgress;
      case 1:
        return SessionStatus.completed;
      case 2:
        return SessionStatus.abandoned;
      default:
        return SessionStatus.inProgress;
    }
  }

  @override
  void write(BinaryWriter writer, SessionStatus obj) {
    switch (obj) {
      case SessionStatus.inProgress:
        writer.writeByte(0);
      case SessionStatus.completed:
        writer.writeByte(1);
      case SessionStatus.abandoned:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProgressionTypeAdapter extends TypeAdapter<ProgressionType> {
  @override
  final typeId = 14;

  @override
  ProgressionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProgressionType.doubleProgression;
      default:
        return ProgressionType.doubleProgression;
    }
  }

  @override
  void write(BinaryWriter writer, ProgressionType obj) {
    switch (obj) {
      case ProgressionType.doubleProgression:
        writer.writeByte(0);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrainingGoalAdapter extends TypeAdapter<TrainingGoal> {
  @override
  final typeId = 15;

  @override
  TrainingGoal read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TrainingGoal.gainMuscle;
      case 1:
        return TrainingGoal.maintain;
      case 2:
        return TrainingGoal.cut;
      default:
        return TrainingGoal.gainMuscle;
    }
  }

  @override
  void write(BinaryWriter writer, TrainingGoal obj) {
    switch (obj) {
      case TrainingGoal.gainMuscle:
        writer.writeByte(0);
      case TrainingGoal.maintain:
        writer.writeByte(1);
      case TrainingGoal.cut:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UnitSystemAdapter extends TypeAdapter<UnitSystem> {
  @override
  final typeId = 16;

  @override
  UnitSystem read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UnitSystem.metric;
      case 1:
        return UnitSystem.imperial;
      default:
        return UnitSystem.metric;
    }
  }

  @override
  void write(BinaryWriter writer, UnitSystem obj) {
    switch (obj) {
      case UnitSystem.metric:
        writer.writeByte(0);
      case UnitSystem.imperial:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitSystemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
