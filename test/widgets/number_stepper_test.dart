import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/widgets/number_stepper.dart';

void main() {
  Future<List<double>> tapStepper(
    WidgetTester tester, {
    required double value,
    required String tooltip,
    double min = 1,
  }) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: NumberStepper(
            label: 'kg',
            value: value,
            step: 1,
            min: min,
            max: 1000,
            decimals: true,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip(tooltip));
    return changes;
  }

  testWidgets('+ moves an off-grid weight up to the next step', (tester) async {
    expect(await tapStepper(tester, value: 32.5, tooltip: 'Increase kg'), [33]);
  });

  testWidgets('− moves an off-grid weight down to the previous step', (
    tester,
  ) async {
    expect(await tapStepper(tester, value: 32.5, tooltip: 'Decrease kg'), [32]);
  });

  testWidgets('on-grid weights move by exactly one step', (tester) async {
    expect(await tapStepper(tester, value: 30, tooltip: 'Increase kg'), [31]);
  });

  testWidgets('− never goes below the minimum', (tester) async {
    expect(await tapStepper(tester, value: 1.5, tooltip: 'Decrease kg'), [1]);
  });

  testWidgets('− from one step reaches a smaller minimum like 0.5', (
    tester,
  ) async {
    expect(
      await tapStepper(tester, value: 1, tooltip: 'Decrease kg', min: 0.5),
      [0.5],
    );
  });
}
