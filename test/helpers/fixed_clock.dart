import 'package:gainit/core/services/clock.dart';

/// Deterministic [Clock] for tests.
class FixedClock implements Clock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}
