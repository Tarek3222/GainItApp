part of 'active_workout_cubit.dart';

sealed class ActiveWorkoutState extends Equatable {
  const ActiveWorkoutState();

  @override
  List<Object?> get props => [];
}

final class ActiveWorkoutLoading extends ActiveWorkoutState {
  const ActiveWorkoutLoading();
}

final class ActiveWorkoutLoaded extends ActiveWorkoutState {
  const ActiveWorkoutLoaded({
    required this.workout,
    this.message,
    this.messageId = 0,
  });

  final ActiveWorkout workout;

  /// One-off feedback (e.g. a failed save). [messageId] changes every time a
  /// message is raised so identical consecutive messages are still shown.
  final String? message;
  final int messageId;

  ActiveWorkoutLoaded copyWith({
    ActiveWorkout? workout,
    String? message,
    int? messageId,
  }) {
    return ActiveWorkoutLoaded(
      workout: workout ?? this.workout,
      message: message ?? this.message,
      messageId: messageId ?? this.messageId,
    );
  }

  @override
  List<Object?> get props => [workout, message, messageId];
}

final class ActiveWorkoutError extends ActiveWorkoutState {
  const ActiveWorkoutError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The workout was finished or discarded; the view navigates away.
final class ActiveWorkoutClosed extends ActiveWorkoutState {
  const ActiveWorkoutClosed({required this.sessionId, required this.completed});

  final String sessionId;
  final bool completed;

  @override
  List<Object?> get props => [sessionId, completed];
}
