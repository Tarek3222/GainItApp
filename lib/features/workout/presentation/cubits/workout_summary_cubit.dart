import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../domain/entities/workout_summary.dart';
import '../../domain/usecases/get_workout_summary_use_case.dart';

part 'workout_summary_state.dart';

class WorkoutSummaryCubit extends Cubit<WorkoutSummaryState> {
  WorkoutSummaryCubit({required this.sessionId, required this._getSummary})
    : super(const WorkoutSummaryLoading());

  final String sessionId;
  final GetWorkoutSummaryUseCase _getSummary;

  Future<void> load() async {
    emit(const WorkoutSummaryLoading());
    final result = await _getSummary(sessionId);
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => WorkoutSummaryError(failure.userMessage),
        WorkoutSummaryLoaded.new,
      ),
    );
  }
}
