// Storage note: Hive stores these enums by their index. Only ever append new
// values at the end. Reordering or removing values corrupts saved data.

/// Muscle groups used for exercise mapping and volume calculation.
enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  traps('Traps'),
  frontDelts('Front delts'),
  sideDelts('Side delts'),
  rearDelts('Rear delts'),
  biceps('Biceps'),
  triceps('Triceps'),
  forearms('Forearms'),
  quads('Quads'),
  hamstrings('Hamstrings'),
  glutes('Glutes'),
  calves('Calves'),
  lowerBack('Lower back'),
  abs('Abs');

  const MuscleGroup(this.label);

  final String label;
}

enum ExerciseCategory { compound, isolation }

enum DayType { workout, rest }

enum SessionStatus { inProgress, completed, abandoned }

enum ProgressionType { doubleProgression }

enum TrainingGoal {
  gainMuscle('Gain muscle'),
  maintain('Maintain'),
  cut('Cut');

  const TrainingGoal(this.label);

  final String label;
}

/// How weights and heights are shown. Storage is always kg / cm.
enum UnitSystem { metric, imperial }

/// Kinds of daily goal. Water and steps have their own units and tracking;
/// custom goals carry a name and unit.
enum DailyGoalType { water, steps, custom }
