import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/entities/user_profile.dart';
import 'package:gainit/core/domain/entities/workout_session.dart';
import 'package:gainit/core/storage/adapters/hive_adapters.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../helpers/hive_test_harness.dart';

/// Writes a set log the way an older app version would have: required
/// fields only, with no `rir`, `isWarmup`, `notes` or `plannedWeight`.
class _LegacySetLogAdapter extends TypeAdapter<_LegacySetLog> {
  @override
  int get typeId => SetLogAdapter().typeId;

  @override
  _LegacySetLog read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, _LegacySetLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write('legacy')
      ..writeByte(1)
      ..write('se1')
      ..writeByte(2)
      ..write(1)
      ..writeByte(3)
      ..write(6)
      ..writeByte(4)
      ..write(10)
      ..writeByte(6)
      ..write(40.0)
      ..writeByte(7)
      ..write(8)
      ..writeByte(9)
      ..write(DateTime(2026, 3, 2));
  }
}

class _LegacySetLog {
  const _LegacySetLog();
}

/// Writes a profile the way version 0.1.0 did: no birth year or photo.
class _LegacyProfileAdapter extends TypeAdapter<_LegacyProfile> {
  @override
  int get typeId => UserProfileAdapter().typeId;

  @override
  _LegacyProfile read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, _LegacyProfile obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write('me')
      ..writeByte(1)
      ..write('Old Timer')
      ..writeByte(2)
      ..write(180.0)
      ..writeByte(3)
      ..write(TrainingGoal.maintain)
      ..writeByte(4)
      ..write(DateTime(2026))
      ..writeByte(5)
      ..write(UnitSystem.metric)
      ..writeByte(6)
      ..write(DateTime(2026))
      ..writeByte(7)
      ..write(DateTime(2026));
  }
}

class _LegacyProfile {
  const _LegacyProfile();
}

void main() {
  final harness = HiveTestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('type IDs of shipped types never change', () {
    // Changing any of these would make existing data unreadable.
    expect(UserProfileAdapter().typeId, 1);
    expect(ProgramAdapter().typeId, 2);
    expect(WorkoutDayAdapter().typeId, 3);
    expect(ExerciseAdapter().typeId, 4);
    expect(ProgramExerciseAdapter().typeId, 5);
    expect(WorkoutSessionAdapter().typeId, 6);
    expect(SessionExerciseAdapter().typeId, 7);
    expect(SetLogAdapter().typeId, 8);
    expect(BodyWeightEntryAdapter().typeId, 9);
  });

  test('session exercise round-trips through disk', () async {
    const exercise = SessionExercise(
      id: 'se1',
      sessionId: 's1',
      programExerciseId: 'pe1',
      exerciseId: 'ex1',
      exerciseName: 'Bench',
      primaryMuscle: MuscleGroup.chest,
      category: ExerciseCategory.compound,
      orderIndex: 2,
      targetSets: 3,
      repMin: 6,
      repMax: 10,
      restSeconds: 120,
      rirMin: 1,
      rirMax: 3,
      weightStep: 2.5,
      supersetGroup: 1,
      isSkipped: true,
    );
    final box = harness.storage.sessionExercises;

    await box.put(exercise.id, exercise);
    await box.close();
    final reopened = await Hive.openBox<SessionExercise>(box.name);

    expect(reopened.get('se1'), exercise);
  });

  test('enum lists round-trip', () async {
    final exercise = Exercise(
      id: 'ex1',
      name: 'Row',
      primaryMuscle: MuscleGroup.back,
      secondaryMuscles: const [MuscleGroup.biceps, MuscleGroup.rearDelts],
      category: ExerciseCategory.compound,
      createdAt: DateTime(2026),
    );
    final box = harness.storage.exercises;

    await box.put(exercise.id, exercise);
    await box.close();
    final reopened = await Hive.openBox<Exercise>(box.name);

    expect(reopened.get('ex1'), exercise);
  });

  test('set log round-trips with nullable fields', () async {
    final set = SetLog(
      id: 'set1',
      sessionExerciseId: 'se1',
      setNumber: 1,
      plannedRepsMin: 6,
      plannedRepsMax: 10,
      actualWeight: 32.5,
      actualReps: 8,
      completedAt: DateTime(2026, 3, 2, 18, 30),
    );

    await harness.storage.setLogs.put(set.id, set);

    expect(harness.storage.setLogs.get('set1'), set);
  });

  test('older records without optional fields load with defaults', () async {
    final raw = await Hive.openBox<Object?>('legacy_box');
    Hive.registerAdapter<_LegacySetLog>(_LegacySetLogAdapter(), override: true);
    await raw.put('k', const _LegacySetLog());
    await raw.close();
    Hive.registerAdapter<SetLog>(SetLogAdapter(), override: true);

    final reopened = await Hive.openBox<Object?>('legacy_box');
    final set = reopened.get('k')! as SetLog;

    expect(set.id, 'legacy');
    expect(set.actualWeight, 40);
    expect(set.actualReps, 8);
    expect(set.isWarmup, isFalse);
    expect(set.rir, isNull);
    expect(set.notes, isNull);
  });

  test('profile with age, photo and imperial units round-trips', () async {
    final profile = UserProfile(
      id: 'me',
      name: 'Sam',
      heightCm: 180,
      goal: TrainingGoal.cut,
      trainingStartDate: DateTime(2026, 3),
      createdAt: DateTime(2026, 3),
      updatedAt: DateTime(2026, 3),
      unitSystem: UnitSystem.imperial,
      birthDate: DateTime(1996, 3, 1),
      photoPath: '/data/media/me.jpg',
    );

    await harness.storage.profile.put('me', profile);

    expect(harness.storage.profile.get('me'), profile);
  });

  test('a profile saved before age and photo existed still loads', () async {
    final raw = await Hive.openBox<Object?>('legacy_profile_box');
    Hive.registerAdapter<_LegacyProfile>(
      _LegacyProfileAdapter(),
      override: true,
    );
    await raw.put('me', const _LegacyProfile());
    await raw.close();
    Hive.registerAdapter<UserProfile>(UserProfileAdapter(), override: true);

    final reopened = await Hive.openBox<Object?>('legacy_profile_box');
    final profile = reopened.get('me')! as UserProfile;

    expect(profile.name, 'Old Timer');
    expect(profile.unitSystem, UnitSystem.metric);
    expect(profile.birthDate, isNull);
    expect(profile.photoPath, isNull);
  });
}
