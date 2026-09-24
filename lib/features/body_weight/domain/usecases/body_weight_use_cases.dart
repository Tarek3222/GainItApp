import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/body_weight_entry.dart';
import '../../../../core/domain/training/body_weight_trend.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/result/failures.dart';
import '../../../../core/services/clock.dart';
import '../../../../core/services/id_generator.dart';
import '../repositories/body_weight_repository.dart';

class BodyWeightOverview extends Equatable {
  const BodyWeightOverview({
    required this.entries,
    required this.points,
    required this.trend,
    this.summary,
  });

  /// Most recent first.
  final List<BodyWeightEntry> entries;

  /// Raw weigh-ins, oldest first (chart).
  final List<WeightPoint> points;

  /// 7-day rolling average, oldest first (chart).
  final List<WeightPoint> trend;
  final BodyWeightSummary? summary;

  bool get isEmpty => entries.isEmpty;

  @override
  List<Object?> get props => [entries, points, trend, summary];
}

class WatchBodyWeightUseCase {
  const WatchBodyWeightUseCase(this._repository);

  final BodyWeightRepository _repository;

  Stream<ApiResult<BodyWeightOverview>> call() =>
      _repository.watchEntries().map((r) => r.map(build));

  static BodyWeightOverview build(List<BodyWeightEntry> entries) {
    final ascending = BodyWeightTrend.sortedAscending(entries);
    return BodyWeightOverview(
      entries: ascending.reversed.toList(),
      points: [
        for (final e in ascending) WeightPoint(e.measuredAt, e.weightKg),
      ],
      trend: BodyWeightTrend.rollingAverage(ascending),
      summary: BodyWeightTrend.summary(ascending),
    );
  }
}

class AddBodyWeightUseCase {
  const AddBodyWeightUseCase(this._repository, this._clock, this._ids);

  final BodyWeightRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  Future<VoidResult> call(double weightKg, {DateTime? measuredAt}) async {
    final entry = BodyWeightEntry(
      id: _ids.next(),
      weightKg: weightKg,
      measuredAt: measuredAt ?? _clock.now(),
    );
    final errors = Validators.bodyWeight(entry);
    if (errors.isNotEmpty) return ApiFailure(ValidationFailure(errors));
    return _repository.save(entry);
  }
}

class DeleteBodyWeightUseCase {
  const DeleteBodyWeightUseCase(this._repository);

  final BodyWeightRepository _repository;

  Future<VoidResult> call(String id) => _repository.delete(id);
}
