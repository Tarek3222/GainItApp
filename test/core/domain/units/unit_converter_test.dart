import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/units/unit_converter.dart';

void main() {
  test('kg and lb convert both ways', () {
    expect(UnitConverter.kgToLb(100), closeTo(220.462, 0.001));
    expect(UnitConverter.lbToKg(220.462), closeTo(100, 0.001));
  });

  test('cm splits into whole feet and inches', () {
    expect(UnitConverter.cmToFeetInches(180), (feet: 5, inches: 11));
    expect(UnitConverter.cmToFeetInches(152.4), (feet: 5, inches: 0));
  });

  test('inches never round up to 12', () {
    // 182.8 cm = 71.97 in → 72 in → 6′0″, not 5′12″.
    expect(UnitConverter.cmToFeetInches(182.8), (feet: 6, inches: 0));
  });

  test('feet and inches convert back to cm', () {
    expect(UnitConverter.feetInchesToCm(5, 11), closeTo(180.34, 0.001));
  });
}
