import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../domain/entities/enums.dart';
import '../domain/units/unit_converter.dart';
import '../presentation/units/unit_format.dart';

/// A scroll wheel over the whole numbers [min]..[max]. Replaces typed input
/// for body measurements: the user flicks to a value instead of typing.
class WheelNumberPicker extends StatefulWidget {
  const WheelNumberPicker({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.format,
    this.width = 72,
  });

  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;
  final String semanticLabel;
  final String Function(int value)? format;
  final double width;

  static const itemExtent = 40.0;
  static const height = itemExtent * 4;

  @override
  State<WheelNumberPicker> createState() => _WheelNumberPickerState();
}

class _WheelNumberPickerState extends State<WheelNumberPicker> {
  late final FixedExtentScrollController _controller;

  int _indexOf(int value) =>
      (value.clamp(widget.min, widget.max) - widget.min).toInt();

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: _indexOf(widget.value),
    );
  }

  @override
  void didUpdateWidget(WheelNumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow external changes (e.g. switching kg ↔ lb) without animating.
    final target = _indexOf(widget.value);
    if (_controller.hasClients && _controller.selectedItem != target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToItem(target);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final target = _indexOf(widget.value + delta);
    _controller.animateToItem(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _onSelected(int index) {
    final value = widget.min + index;
    if (value == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = widget.format ?? (v) => '$v';
    final canIncrease = widget.value < widget.max;
    final canDecrease = widget.value > widget.min;
    // Screen readers can't flick a wheel: expose increase / decrease too.
    return Semantics(
      label: widget.semanticLabel,
      value: format(widget.value),
      increasedValue: canIncrease ? format(widget.value + 1) : null,
      decreasedValue: canDecrease ? format(widget.value - 1) : null,
      onIncrease: canIncrease ? () => _step(1) : null,
      onDecrease: canDecrease ? () => _step(-1) : null,
      child: SizedBox(
        width: widget.width,
        height: WheelNumberPicker.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: WheelNumberPicker.itemExtent,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.smAll,
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: WheelNumberPicker.itemExtent,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.004,
              overAndUnderCenterOpacity: 0.35,
              onSelectedItemChanged: _onSelected,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.max - widget.min + 1,
                builder: (context, index) => Center(
                  child: Text(
                    format(widget.min + index),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled card around one or more wheels.
///
/// While not [isSet] the wheel shows a suggested value, the header reads
/// "Not set" and a "Use …" button confirms the suggestion as-is, so a
/// default is never saved without the user choosing it.
class MeasurePickerCard extends StatelessWidget {
  const MeasurePickerCard({
    super.key,
    required this.title,
    required this.summary,
    required this.children,
    this.isSet = true,
    this.onConfirm,
    this.errorText,
  });

  final String title;

  /// Current value in words, e.g. "180 cm".
  final String summary;
  final List<Widget> children;
  final bool isSet;
  final VoidCallback? onConfirm;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = errorText;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semanticColors.elevated,
        borderRadius: AppRadius.mdAll,
        border: error == null
            ? null
            : Border.all(color: theme.colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                isSet ? summary : 'pickers.notSet'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isSet
                      ? theme.colorScheme.primary
                      : context.semanticColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
          if (!isSet && onConfirm != null)
            Align(
              child: TextButton(
                onPressed: onConfirm,
                child: Text('pickers.use'.tr(namedArgs: {'value': summary})),
              ),
            ),
          if (error != null)
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitLabel extends StatelessWidget {
  const _UnitLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
  );
}

/// Height in cm (metric) or feet + inches (imperial). Always reports cm,
/// clamped to [minCm]..[maxCm].
class HeightPicker extends StatelessWidget {
  const HeightPicker({
    super.key,
    required this.heightCm,
    required this.system,
    required this.onChanged,
    this.isSet = true,
    this.onConfirm,
    this.errorText,
  });

  final double heightCm;
  final UnitSystem system;
  final ValueChanged<double> onChanged;
  final bool isSet;
  final VoidCallback? onConfirm;
  final String? errorText;

  static const minCm = 100;
  static const maxCm = 250;

  double _clamp(double cm) => cm.clamp(minCm, maxCm).toDouble();

  @override
  Widget build(BuildContext context) {
    final units = UnitFormat(system);
    if (units.isMetric) {
      return MeasurePickerCard(
        title: 'pickers.height'.tr(),
        summary: units.height(heightCm),
        isSet: isSet,
        onConfirm: onConfirm,
        errorText: errorText,
        children: [
          WheelNumberPicker(
            min: minCm,
            max: maxCm,
            value: heightCm.round(),
            semanticLabel: 'pickers.heightCm'.tr(),
            onChanged: (cm) => onChanged(cm.toDouble()),
          ),
          _UnitLabel('units.cm'.tr()),
        ],
      );
    }
    final (:feet, :inches) = UnitConverter.cmToFeetInches(heightCm);
    return MeasurePickerCard(
      title: 'pickers.height'.tr(),
      summary: units.height(heightCm),
      isSet: isSet,
      onConfirm: onConfirm,
      errorText: errorText,
      children: [
        WheelNumberPicker(
          min: 3,
          max: 8,
          value: feet,
          width: 56,
          semanticLabel: 'pickers.heightFeet'.tr(),
          onChanged: (ft) =>
              onChanged(_clamp(UnitConverter.feetInchesToCm(ft, inches))),
        ),
        _UnitLabel('units.ft'.tr()),
        WheelNumberPicker(
          min: 0,
          max: 11,
          value: inches,
          width: 56,
          semanticLabel: 'pickers.heightInches'.tr(),
          onChanged: (inch) =>
              onChanged(_clamp(UnitConverter.feetInchesToCm(feet, inch))),
        ),
        _UnitLabel('units.inch'.tr()),
      ],
    );
  }
}

/// Body weight to 0.1 in kg or lb. Always reports kg.
class BodyWeightPicker extends StatelessWidget {
  const BodyWeightPicker({
    super.key,
    required this.weightKg,
    required this.system,
    required this.onChanged,
    this.title = 'Weight',
    this.isSet = true,
    this.onConfirm,
    this.errorText,
  });

  final double weightKg;
  final UnitSystem system;
  final ValueChanged<double> onChanged;
  final String title;
  final bool isSet;
  final VoidCallback? onConfirm;
  final String? errorText;

  /// Body-weight limits (see `Validators.bodyWeight`), in each unit's whole
  /// numbers so every wheel position is valid.
  static const _minKg = 20;
  static const _maxKg = 400;
  static const _minLb = 45;
  static const _maxLb = 881;

  @override
  Widget build(BuildContext context) {
    final units = UnitFormat(system);
    final tenths = (units.toDisplayWeight(weightKg) * 10).round();
    final whole = tenths ~/ 10;
    final decimal = tenths % 10;

    void emit(int w, int d) {
      // Clamp: e.g. 400.5 kg or 881.9 lb would exceed the 400 kg limit.
      final kg = units
          .fromDisplayWeight(w + d / 10)
          .clamp(_minKg.toDouble(), _maxKg.toDouble());
      onChanged(double.parse(kg.toStringAsFixed(3)));
    }

    return MeasurePickerCard(
      title: title,
      summary: units.weight(weightKg),
      isSet: isSet,
      onConfirm: onConfirm,
      errorText: errorText,
      children: [
        WheelNumberPicker(
          min: units.isMetric ? _minKg : _minLb,
          max: units.isMetric ? _maxKg : _maxLb,
          value: whole,
          width: 80,
          semanticLabel: 'pickers.weightWhole'.tr(
            namedArgs: {'unit': units.weightUnit},
          ),
          onChanged: (w) => emit(w, decimal),
        ),
        const _UnitLabel('.'),
        WheelNumberPicker(
          min: 0,
          max: 9,
          value: decimal,
          width: 48,
          semanticLabel: 'pickers.weightTenths'.tr(),
          onChanged: (d) => emit(whole, d),
        ),
        _UnitLabel(units.weightUnit),
      ],
    );
  }
}

class AgePicker extends StatelessWidget {
  const AgePicker({
    super.key,
    required this.age,
    required this.onChanged,
    this.isSet = true,
    this.onConfirm,
    this.errorText,
    this.min = 13,
    this.max = 90,
  });

  static const defaultAge = 25;

  final int age;
  final ValueChanged<int> onChanged;

  /// `false` shows "Not set" until the user scrolls or confirms.
  final bool isSet;
  final VoidCallback? onConfirm;
  final String? errorText;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return MeasurePickerCard(
      title: 'pickers.age'.tr(),
      summary: 'pickers.ageYears'.tr(namedArgs: {'age': '$age'}),
      isSet: isSet,
      onConfirm: onConfirm,
      errorText: errorText,
      children: [
        WheelNumberPicker(
          min: min,
          max: max,
          value: age,
          semanticLabel: 'pickers.ageInYears'.tr(),
          onChanged: onChanged,
        ),
        _UnitLabel('units.years'.tr()),
      ],
    );
  }
}

/// kg · cm / lb · ft switch.
class UnitSystemToggle extends StatelessWidget {
  const UnitSystemToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UnitSystem value;
  final ValueChanged<UnitSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UnitSystem>(
      segments: [
        ButtonSegment(
          value: UnitSystem.metric,
          label: Text('units.metricToggle'.tr()),
        ),
        ButtonSegment(
          value: UnitSystem.imperial,
          label: Text('units.imperialToggle'.tr()),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
