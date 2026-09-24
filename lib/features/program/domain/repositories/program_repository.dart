import '../../../../core/domain/entities/program.dart';
import '../../../../core/result/api_result.dart';
import '../entities/plan_entities.dart';

abstract interface class ProgramRepository {
  Stream<ApiResult<WeekPlanData>> watchWeek();

  /// With [withHistory] false, past performances are left out (cheaper;
  /// used by the day editor, which shows no targets).
  Stream<ApiResult<WorkoutDayData>> watchWorkoutDay(
    String dayId, {
    bool withHistory = true,
  });

  Future<ApiResult<WorkoutDay>> getDay(String dayId);

  Future<ApiResult<Exercise>> getExercise(String exerciseId);

  /// Number of exercises configured for [dayId].
  Future<ApiResult<int>> exerciseCount(String dayId);

  Future<VoidResult> saveDay(WorkoutDay day);

  /// Adds or updates one exercise entry of a day.
  Future<VoidResult> saveDayExercise(ProgramExercise entry);

  Future<VoidResult> removeDayExercise(String entryId);

  Future<VoidResult> reorderDayExercises(String dayId, List<String> entryIds);
}
