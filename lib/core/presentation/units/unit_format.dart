import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/enums.dart';
import '../../domain/units/unit_converter.dart';
import '../../utils/formatters.dart';

/// Formats stored kg / cm values in the user's unit system, and converts
/// edited display values back to storage units.
class UnitFormat {
  const UnitFormat(this.system);

  final UnitSystem system;

  bool get isMetric => system == UnitSystem.metric;

  String get weightUnit => (isMetric ? 'units.kg' : 'units.lb').tr();

  String get heightUnit => (isMetric ? 'units.cm' : 'units.ft').tr();

  /// kg → value in the display unit (rounded to 2 decimals).
  double toDisplayWeight(double kg) => double.parse(
    (isMetric ? kg : UnitConverter.kgToLb(kg)).toStringAsFixed(2),
  );

  /// Display value → kg for storage.
  double fromDisplayWeight(double value) =>
      isMetric ? value : UnitConverter.lbToKg(value);

  /// Formats a value already in the display unit: kg keep up to 2 decimals
  /// (e.g. 31.25), lb are rounded to 1 decimal.
  String formatDisplay(double value) => Formatters.weight(
    isMetric ? value : double.parse(value.toStringAsFixed(1)),
  );

  /// "72.4" / "159.6" — number only.
  String weightValue(double kg) => formatDisplay(toDisplayWeight(kg));

  /// "72.4 kg" / "159.6 lb".
  String weight(double kg) => '${weightValue(kg)} $weightUnit';

  /// "+2.5 kg" / "−1.1 lb" / "±0 kg". The sign follows the rounded value,
  /// so a tiny change never shows as "−0".
  String signedWeight(double kg) {
    final text = weightValue(kg.abs());
    final shown = double.parse(text);
    final sign = shown == 0 ? '±' : (kg > 0 ? '+' : '−');
    return '$sign$text $weightUnit';
  }

  String get waterUnit => (isMetric ? 'units.ml' : 'units.flOz').tr();

  /// ml → value in the display unit (fl oz rounded to 1 decimal).
  double toDisplayWater(double ml) => isMetric
      ? ml.roundToDouble()
      : double.parse(UnitConverter.mlToFlOz(ml).toStringAsFixed(1));

  /// Display value → ml for storage.
  double fromDisplayWater(double value) =>
      isMetric ? value : UnitConverter.flOzToMl(value);

  /// Quick-add sizes in ml: a glass and a bottle (250 / 500 ml, or
  /// 8 / 16 fl oz).
  List<double> get waterServingsMl => isMetric
      ? const [250, 500]
      : [UnitConverter.flOzToMl(8), UnitConverter.flOzToMl(16)];

  /// Step for editing a water target in display units.
  double get waterTargetStep => isMetric ? 250 : 8;

  /// "750 ml" / "1.5 L" / "25 fl oz".
  String water(double ml) {
    if (!isMetric) return '${_oz(ml)} $waterUnit';
    return ml >= 1000
        ? '${Formatters.weight(_litres(ml))} ${'units.litre'.tr()}'
        : '${ml.round()} $waterUnit';
  }

  /// Today's water against the target in one unit: "1.25 / 3 L",
  /// "400 / 750 ml", "42 / 101 fl oz".
  String waterProgress(double ml, double targetMl) {
    if (!isMetric) return '${_oz(ml)} / ${_oz(targetMl)} $waterUnit';
    if (targetMl < 1000) {
      return '${ml.round()} / ${targetMl.round()} $waterUnit';
    }
    return '${Formatters.weight(_litres(ml))} / '
        '${Formatters.weight(_litres(targetMl))} ${'units.litre'.tr()}';
  }

  static double _litres(double ml) => (ml / 10).round() / 100;

  static String _oz(double ml) =>
      Formatters.weight((UnitConverter.mlToFlOz(ml) * 10).round() / 10);

  /// "180 cm" / "5′11″".
  String height(double cm) {
    if (isMetric) return '${cm.round()} $heightUnit';
    final (:feet, :inches) = UnitConverter.cmToFeetInches(cm);
    return '$feet′$inches″';
  }
}

/// Provides the current [UnitFormat] to the widget tree.
class UnitScope extends InheritedWidget {
  const UnitScope({super.key, required this.system, required super.child});

  final UnitSystem system;

  /// Metric when no scope is above [context] (e.g. isolated widget tests).
  static UnitFormat of(BuildContext context) => UnitFormat(
    context.dependOnInheritedWidgetOfExactType<UnitScope>()?.system ??
        UnitSystem.metric,
  );

  @override
  bool updateShouldNotify(UnitScope oldWidget) => system != oldWidget.system;
}

extension UnitsContext on BuildContext {
  UnitFormat get units => UnitScope.of(this);
}
