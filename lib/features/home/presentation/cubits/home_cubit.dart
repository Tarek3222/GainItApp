import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../../body_weight/domain/usecases/body_weight_use_cases.dart';
import '../../../workout/domain/usecases/start_workout_use_case.dart';
import '../../domain/entities/home_dashboard.dart';
import '../../domain/usecases/watch_home_dashboard_use_case.dart';

class HomeCubit extends StreamViewCubit<HomeDashboard> {
  HomeCubit({
    required this._watchDashboard,
    required this._startWorkout,
    required this._addBodyWeight,
  });

  final WatchHomeDashboardUseCase _watchDashboard;
  final StartWorkoutUseCase _startWorkout;
  final AddBodyWeightUseCase _addBodyWeight;

  @override
  Stream<ApiResult<HomeDashboard>> source() => _watchDashboard();

  /// Resolves to the session ID to open.
  Future<ActionOutcome<String>> startWorkout(String dayId) async =>
      ActionOutcome.from(await _startWorkout(dayId));

  Future<ActionOutcome<void>> logBodyWeight(double kg) async =>
      ActionOutcome.from(await _addBodyWeight(kg));
}
