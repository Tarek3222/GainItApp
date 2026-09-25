import 'dart:async';

import 'package:gainit/core/domain/services/step_counter.dart';

/// Scripted [StepCounter]: push sensor readings with [emit] and failures
/// with [fail].
class FakeStepCounter implements StepCounter {
  FakeStepCounter({this.access = StepAccess.granted, this.afterRequest});

  StepAccess access;

  /// Access after the user answers the permission prompt.
  StepAccess? afterRequest;

  final _readings = StreamController<int>.broadcast();
  var requests = 0;
  var settingsOpened = 0;

  bool get isListening => _readings.hasListener;

  void emit(int stepsSinceBoot) => _readings.add(stepsSinceBoot);

  void fail() => _readings.addError(StateError('StepCount not available'));

  @override
  Future<StepAccess> checkAccess() async => access;

  @override
  Future<StepAccess> requestAccess() async {
    requests++;
    access = afterRequest ?? access;
    return access;
  }

  @override
  Stream<int> stepsSinceBoot() => _readings.stream;

  @override
  Future<void> openSettings() async => settingsOpened++;
}
