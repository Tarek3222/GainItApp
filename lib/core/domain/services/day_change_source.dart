/// Signals that "today" may have changed: at local midnight, and when the
/// app comes back to the foreground. Date-based use cases (dashboard, plan,
/// weekly volume) recompute on it so they never show yesterday's state.
abstract interface class DayChangeSource {
  Stream<void> get changes;
}
