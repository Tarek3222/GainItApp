/// Injectable time source so time-dependent logic is deterministic in tests
/// (see `test/helpers/fixed_clock.dart`).
class Clock {
  const Clock();

  DateTime now() => DateTime.now();
}
