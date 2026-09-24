import '../../../../core/result/api_result.dart';
import '../entities/plan_entities.dart';

abstract interface class ProgramRepository {
  Stream<ApiResult<WeekPlanData>> watchWeek();

  Stream<ApiResult<WorkoutDayData>> watchWorkoutDay(String dayId);
}
