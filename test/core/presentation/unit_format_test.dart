import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/presentation/units/unit_format.dart';

void main() {
  const metric = UnitFormat(UnitSystem.metric);
  const imperial = UnitFormat(UnitSystem.imperial);

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
