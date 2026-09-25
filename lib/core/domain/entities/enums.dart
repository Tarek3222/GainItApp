// Storage note: Hive stores these enums by their index. Only ever append new
// values at the end. Reordering or removing values corrupts saved data.

/// Muscle groups used for exercise mapping and volume calculation.
/// Display names live in `core/l10n/enum_labels.dart`.
enum MuscleGroup {
  chest,
  back,
  traps,
  frontDelts,
  sideDelts,
  rearDelts,
  biceps,
  triceps,
  forearms,
  quads,
  hamstrings,
  glutes,
  calves,
  lowerBack,
  abs,
}

enum ExerciseCategory { compound, isolation }

enum DayType { workout, rest }

enum SessionStatus { inProgress, completed, abandoned }

enum ProgressionType { doubleProgression }

enum TrainingGoal { gainMuscle, maintain, cut }

/// How weights and heights are shown. Storage is always kg / cm.
enum UnitSystem { metric, imperial }

/// Kinds of daily goal. Water and steps have their own units and tracking;
/// custom goals carry a name and unit.
enum DailyGoalType { water, steps, custom }
