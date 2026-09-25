/// Whether the app may read the phone's step sensor.
enum StepAccess {
  granted,

  /// Not granted yet; asking may show the system prompt.
  denied,

  /// Refused for good; only the system settings can change it.
  permanentlyDenied,

  /// This platform has no step sensor the app can use.
  unsupported,
}

/// The phone's built-in step counter.
abstract interface class StepCounter {
  /// Current access, without asking the user.
  Future<StepAccess> checkAccess();

  /// Asks for access when the system still allows asking.
  Future<StepAccess> requestAccess();

  /// Steps since the phone last booted. Emits an error when the phone has
  /// no step sensor.
  Stream<int> stepsSinceBoot();

  /// Opens this app's page in the system settings.
  Future<void> openSettings();
}
