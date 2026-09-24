import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/view_state.dart';
import '../../../../core/result/api_result.dart';
import '../../domain/usecases/body_weight_use_cases.dart';

class BodyWeightCubit extends StreamViewCubit<BodyWeightOverview> {
  BodyWeightCubit({
    required this._watch,
    required this._add,
    required this._delete,
  });

  final WatchBodyWeightUseCase _watch;
  final AddBodyWeightUseCase _add;
  final DeleteBodyWeightUseCase _delete;

  @override
  Stream<ApiResult<BodyWeightOverview>> source() => _watch();

  Future<ActionOutcome<void>> add(
    double weightKg, {
    DateTime? measuredAt,
  }) async => ActionOutcome.from(await _add(weightKg, measuredAt: measuredAt));

  Future<ActionOutcome<void>> delete(String id) async =>
      ActionOutcome.from(await _delete(id));
}
