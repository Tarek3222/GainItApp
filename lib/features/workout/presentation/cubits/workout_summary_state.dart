part of 'workout_summary_cubit.dart';

sealed class WorkoutSummaryState extends Equatable {
  const WorkoutSummaryState();

  @override
  List<Object?> get props => [];
}

final class WorkoutSummaryLoading extends WorkoutSummaryState {
  const WorkoutSummaryLoading();
}

final class WorkoutSummaryLoaded extends WorkoutSummaryState {
  const WorkoutSummaryLoaded(this.summary);

  final WorkoutSummary summary;

  @override
  List<Object?> get props => [summary];
}

final class WorkoutSummaryError extends WorkoutSummaryState {
  const WorkoutSummaryError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
