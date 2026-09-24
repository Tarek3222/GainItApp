import '../entities/app_settings.dart';
import '../entities/body_weight_entry.dart';
import '../entities/program.dart';
import '../entities/user_profile.dart';
import '../entities/workout_session.dart';

/// Data-integrity rules (spec §22). Hive has no CHECK constraints, so every
/// write goes through these before touching storage. Each returns a list of
/// human-readable errors; empty means valid.
abstract final class Validators {
  static const maxWeightKg = 1000.0;

  /// Lightest weight the set editor offers. Any weight above 0 is valid;
  /// this only sets the −/+ floor so small plates stay reachable.
  static const minSetWeightKg = 0.5;
  static const maxReps = 200;
  static const maxRir = 10;

  static List<String> setLog(SetLog set) => [
    if (set.setNumber < 1) 'Set number must be at least 1.',
    if (set.actualReps < 1) 'A working set needs at least 1 rep.',
    if (set.actualReps > maxReps) 'Reps must be $maxReps or fewer.',
    if (set.actualWeight <= 0) 'Weight must be above 0.',
    if (set.actualWeight > maxWeightKg) 'Weight must be under $maxWeightKg kg.',
    if (set.actualWeight.isNaN) 'Weight must be a number.',
    if (set.rir != null && set.rir! < 0) 'RIR cannot be negative.',
    if (set.rir != null && set.rir! > maxRir) 'RIR must be $maxRir or less.',
    if (set.plannedRepsMin < 1) 'Planned minimum reps must be at least 1.',
    if (set.plannedRepsMax < set.plannedRepsMin)
      'Planned maximum reps must not be below the minimum.',
  ];

  static List<String> programExercise(ProgramExercise e) => [
    if (e.workingSets < 1) 'Working sets must be at least 1.',
    if (e.repMin < 1) 'Minimum reps must be at least 1.',
    if (e.repMax < e.repMin) 'Maximum reps must not be below the minimum.',
    if (e.restMinSeconds < 0) 'Rest cannot be negative.',
    if (e.restMaxSeconds < e.restMinSeconds)
      'Maximum rest must not be below the minimum.',
    if (e.rirMin < 0) 'RIR cannot be negative.',
    if (e.rirMax < e.rirMin) 'Maximum RIR must not be below the minimum.',
    if (e.weightStep <= 0) 'Weight step must be positive.',
  ];

  static List<String> sessionExercise(SessionExercise e) => [
    if (e.targetSets < 1) 'Target sets must be at least 1.',
    if (e.repMin < 1) 'Minimum reps must be at least 1.',
    if (e.repMax < e.repMin) 'Maximum reps must not be below the minimum.',
    if (e.restSeconds < 0) 'Rest cannot be negative.',
  ];

  static List<String> bodyWeight(BodyWeightEntry e) => [
    if (e.weightKg.isNaN || e.weightKg < 20 || e.weightKg > 400)
      'Body weight must be between 20 and 400 kg.',
  ];

  static List<String> profile(UserProfile p) => [
    if (p.name.trim().isEmpty) 'Please enter your name.',
    if (p.name.trim().length > 40) 'Name must be 40 characters or fewer.',
    if (p.heightCm.isNaN || p.heightCm < 100 || p.heightCm > 250)
      'Height must be between 100 and 250 cm.',
  ];

  static const minAge = 13;
  static const maxAge = 90;

  static List<String> age(int age) => [
    if (age < minAge || age > maxAge)
      'Age must be between $minAge and $maxAge.',
  ];

  static List<String> program(Program p) => [
    if (p.name.trim().isEmpty) 'A program needs a name.',
  ];

  static List<String> settings(AppSettings s) => [
    if (s.reminderMinutesOfDay < 0 || s.reminderMinutesOfDay >= 24 * 60)
      'Reminder time must be within the day.',
  ];

  static List<String> session(WorkoutSession s) => [
    if (s.completedAt != null && s.completedAt!.isBefore(s.startedAt))
      'A workout cannot finish before it starts.',
  ];
}
