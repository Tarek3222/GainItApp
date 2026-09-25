import 'package:equatable/equatable.dart';

import '../utils/dates.dart';

/// Where today's step count stands relative to the phone's step sensor.
///
/// The sensor reports steps since the phone last booted, so today's steps
/// are the latest reading minus a [baseline] taken for the day.
class StepTrackerState extends Equatable {
  const StepTrackerState({
    required this.dayKey,
    required this.baseline,
    required this.lastCount,
  });

  /// Day the state belongs to, as `yyyymmdd` (see [dayKeyOf]).
  final int dayKey;

  /// Sensor reading that counts as 0 steps today. It goes below 0 after a
  /// reboot, so the steps taken before it are kept.
  final int baseline;

  /// Latest sensor reading.
  final int lastCount;

  int get steps => lastCount > baseline ? lastCount - baseline : 0;

  @override
  List<Object?> get props => [dayKey, baseline, lastCount];
}

/// Turns raw sensor readings into steps per day.
abstract final class StepDayTracker {
  /// Folds a new sensor reading ([count]) taken at [now] into [previous].
  ///
  /// - Same day: a lower reading means the phone rebooted and the sensor
  ///   restarted from 0, so the steps counted so far are carried over.
  /// - First reading of the day after one yesterday: every step since that
  ///   reading counts for today, since the sensor can't tell when they
  ///   happened. Most of them are usually taken after midnight.
  /// - No reading yesterday: the steps before now can't be placed in a day,
  ///   so counting starts from this reading.
  ///
  /// Known limit: a reboot is only noticed when the new reading is lower
  /// than the last one. If the phone restarts and walks past its old count
  /// before the app reads the sensor again, the steps before the restart
  /// are lost for that day.
  static StepTrackerState update(
    StepTrackerState? previous,
    int count,
    DateTime now,
  ) {
    final today = dayKeyOf(now);
    StepTrackerState fresh(int baseline) =>
        StepTrackerState(dayKey: today, baseline: baseline, lastCount: count);

    if (previous == null) return fresh(count);
    final rebooted = count < previous.lastCount;
    if (previous.dayKey == today) {
      return fresh(
        rebooted ? previous.baseline - previous.lastCount : previous.baseline,
      );
    }
    if (previous.dayKey == previousDayKey(today)) {
      return fresh(rebooted ? 0 : previous.lastCount);
    }
    return fresh(count);
  }

  /// Steps recorded for the day of [now]; 0 when [state] is from another
  /// day.
  static int stepsOn(StepTrackerState? state, DateTime now) =>
      state != null && state.dayKey == dayKeyOf(now) ? state.steps : 0;
}
