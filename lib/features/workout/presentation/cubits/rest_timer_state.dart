part of 'rest_timer_cubit.dart';

enum RestTimerStatus { idle, running, paused, finished }

final class RestTimerState extends Equatable {
  const RestTimerState({
    this.status = RestTimerStatus.idle,
    this.total = Duration.zero,
    this.remaining = Duration.zero,
    this.endsAt,
    this.exerciseName = '',
    this.settings = const AppSettings(),
  });

  final RestTimerStatus status;
  final Duration total;
  final Duration remaining;
  final DateTime? endsAt;
  final String exerciseName;
  final AppSettings settings;

  bool get isVisible => status != RestTimerStatus.idle;

  double get fraction {
    if (total.inMilliseconds <= 0) return 0;
    return (remaining.inMilliseconds / total.inMilliseconds).clamp(0, 1);
  }

  RestTimerState copyWith({
    RestTimerStatus? status,
    Duration? total,
    Duration? remaining,
    DateTime? endsAt,
    String? exerciseName,
    AppSettings? settings,
  }) {
    return RestTimerState(
      status: status ?? this.status,
      total: total ?? this.total,
      remaining: remaining ?? this.remaining,
      endsAt: endsAt ?? this.endsAt,
      exerciseName: exerciseName ?? this.exerciseName,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [
    status,
    total,
    remaining,
    endsAt,
    exerciseName,
    settings,
  ];
}
