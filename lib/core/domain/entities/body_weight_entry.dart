import 'package:equatable/equatable.dart';

class BodyWeightEntry extends Equatable {
  const BodyWeightEntry({
    required this.id,
    required this.weightKg,
    required this.measuredAt,
    this.notes,
  });

  final String id;
  final double weightKg;
  final DateTime measuredAt;
  final String? notes;

  @override
  List<Object?> get props => [id, weightKg, measuredAt, notes];
}
