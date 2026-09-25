/// Pure conversions between stored metric values and imperial display
/// values. Storage always stays in kg / cm.
abstract final class UnitConverter {
  static const kgPerLb = 0.45359237;
  static const cmPerInch = 2.54;

  /// US fluid ounce.
  static const mlPerFlOz = 29.5735295625;

  static double kgToLb(double kg) => kg / kgPerLb;

  static double lbToKg(double lb) => lb * kgPerLb;

  static double cmToInches(double cm) => cm / cmPerInch;

  static double inchesToCm(double inches) => inches * cmPerInch;

  /// 180 cm → (feet: 5, inches: 11). Inches are rounded to whole numbers
  /// and never reach 12.
  static ({int feet, int inches}) cmToFeetInches(double cm) {
    final total = cmToInches(cm).round();
    return (feet: total ~/ 12, inches: total % 12);
  }

  static double feetInchesToCm(int feet, int inches) =>
      inchesToCm(feet * 12.0 + inches);

  static double mlToFlOz(double ml) => ml / mlPerFlOz;

  static double flOzToMl(double flOz) => flOz * mlPerFlOz;
}
