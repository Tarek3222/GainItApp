abstract final class OneRepMax {
  /// Epley estimate. Returns 0 for zero reps; the weight itself for 1 rep.
  static double epley(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return double.parse((weight * (1 + reps / 30)).toStringAsFixed(1));
  }
}
