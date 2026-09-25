import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/services/step_counter.dart';

/// [StepCounter] backed by the phone's hardware step sensor.
///
/// Android 10+ needs the activity-recognition permission. On iOS, Core
/// Motion shows its own prompt the first time steps are read, so access is
/// reported as granted and the system handles the question.
class PedometerStepCounter implements StepCounter {
  const PedometerStepCounter();

  @override
  Future<StepAccess> checkAccess() async => switch (defaultTargetPlatform) {
    TargetPlatform.android => _map(await Permission.activityRecognition.status),
    TargetPlatform.iOS => StepAccess.granted,
    _ => StepAccess.unsupported,
  };

  @override
  Future<StepAccess> requestAccess() async => switch (defaultTargetPlatform) {
    TargetPlatform.android => _map(
      await Permission.activityRecognition.request(),
    ),
    TargetPlatform.iOS => StepAccess.granted,
    _ => StepAccess.unsupported,
  };

  @override
  Stream<int> stepsSinceBoot() =>
      Pedometer.stepCountStream.map((event) => event.steps);

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }

  static StepAccess _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return StepAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return StepAccess.permanentlyDenied;
    }
    return StepAccess.denied;
  }
}
