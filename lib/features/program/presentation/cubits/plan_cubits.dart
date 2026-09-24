import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../../workout/domain/usecases/start_workout_use_case.dart';
import '../../domain/entities/plan_entities.dart';
import '../../domain/usecases/watch_weekly_plan_use_case.dart';
import '../../domain/usecases/watch_workout_overview_use_case.dart';

class PlanCubit extends StreamViewCubit<WeeklyPlan> {
  PlanCubit({required this._watchPlan});

  final WatchWeeklyPlanUseCase _watchPlan;

  @override
  Stream<ApiResult<WeeklyPlan>> source() => _watchPlan();
}

class WorkoutOverviewCubit extends StreamViewCubit<WorkoutOverview> {
  WorkoutOverviewCubit({
    required this.dayId,
    required this._watchOverview,
    required this._startWorkout,
  });

  final String dayId;
  final WatchWorkoutOverviewUseCase _watchOverview;
  final StartWorkoutUseCase _startWorkout;

  @override
  Stream<ApiResult<WorkoutOverview>> source() => _watchOverview(dayId);

  /// Resolves to the session ID to open.
  Future<ActionOutcome<String>> startWorkout() async =>
      ActionOutcome.from(await _startWorkout(dayId));
}
