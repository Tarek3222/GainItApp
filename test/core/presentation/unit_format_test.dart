import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/presentation/units/unit_format.dart';

void main() {
  const metric = UnitFormat(UnitSystem.metric);
  const imperial = UnitFormat(UnitSystem.imperial);

  group('water', () {
    test('metric shows ml under a litre and litres above', () {
      expect(metric.water(750), '750 ml');
      expect(metric.water(1500), '1.5 L');
      expect(metric.waterProgress(1250, 3000), '1.25 / 3 L');
      expect(metric.waterProgress(400, 750), '400 / 750 ml');
    });

    test('imperial shows US fluid ounces', () {
      expect(imperial.water(236.6), '8 fl oz');
      expect(imperial.waterProgress(1000, 3000), '33.8 / 101.4 fl oz');
    });

    test('servings are a glass and a bottle in display units', () {
      expect(metric.waterServingsMl, [250, 500]);
      expect(imperial.waterServingsMl.map(imperial.water), [
        '8 fl oz',
        '16 fl oz',
      ]);
    });

    test('display values convert back to ml', () {
      expect(imperial.fromDisplayWater(8), closeTo(236.59, 0.01));
      expect(metric.fromDisplayWater(500), 500);
    });
  });

  test('metric shows stored values unchanged', () {
    expect(metric.weight(72.4), '72.4 kg');
    expect(metric.signedWeight(-0.5), '−0.5 kg');
    expect(metric.height(180), '180 cm');
    expect(metric.fromDisplayWeight(32.5), 32.5);
  });

  test('kg keep 2 decimals; lb are rounded to 1', () {
    expect(metric.weight(31.25), '31.25 kg');
    expect(imperial.formatDisplay(66.14), '66.1');
  });

  test('a change that rounds to zero is shown as ±0', () {
    expect(metric.signedWeight(-0.001), '±0 kg');
    expect(imperial.signedWeight(0.01), '±0 lb');
  });

  test('imperial converts to lb and feet/inches', () {
    expect(imperial.weight(100), '220.5 lb');
    expect(imperial.signedWeight(1), '+2.2 lb');
    expect(imperial.height(180), '5′11″');
  });

  test('imperial display values convert back to kg', () {
    final kg = imperial.fromDisplayWeight(imperial.toDisplayWeight(61.2));
    expect(kg, closeTo(61.2, 0.01));
  });

  testWidgets('UnitScope provides the system; metric without a scope', (
    tester,
  ) async {
    late UnitFormat inside;
    late UnitFormat outside;
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (context) {
              outside = context.units;
              return const SizedBox();
            },
          ),
          UnitScope(
            system: UnitSystem.imperial,
            child: Builder(
              builder: (context) {
                inside = context.units;
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );

    expect(outside.system, UnitSystem.metric);
    expect(inside.system, UnitSystem.imperial);
  });
}
