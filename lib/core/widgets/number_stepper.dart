import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Large −/+ control for weight and reps. Tapping the value opens quick
/// numeric entry (spec §20: avoid tiny text fields).
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.decimals = false,
    this.format,
  });

  final String label;
  final double value;
  final double step;
  final double min;
  final double max;
  final bool decimals;
  final ValueChanged<double> onChanged;
  final String Function(double value)? format;

  double _clamp(double v) => double.parse(v.clamp(min, max).toStringAsFixed(2));

  /// −/+ land on the step grid, so an off-grid value (e.g. 32.5 with a 1 kg
  /// step) moves to 32 / 33 rather than 31.5 / 33.5. Typed values stay exact.
  double get _next => ((value / step) + 1e-9).floor() * step + step;
  double get _previous => ((value / step) - 1e-9).ceil() * step - step;

  String get _text =>
      format?.call(value) ??
      (decimals ? value.toString() : value.toStringAsFixed(0));

  Future<void> _enterValue(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) =>
          _NumberEntryDialog(label: label, initial: _text, decimals: decimals),
    );
    if (result != null) onChanged(_clamp(result));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    return Container(
      decoration: BoxDecoration(
        color: context.semanticColors.elevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            semanticLabel: 'Decrease $label',
            onPressed: value > min ? () => onChanged(_clamp(_previous)) : null,
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: '$label $_text. Tap to type.',
              child: InkWell(
                borderRadius: AppRadius.smAll,
                onTap: () => _enterValue(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _text,
                          style: AppTypography.metricLarge.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            semanticLabel: 'Increase $label',
            onPressed: value < max ? () => onChanged(_clamp(_next)) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.minTouchTarget + AppSpacing.sm,
      height: AppSpacing.minTouchTarget + AppSpacing.md,
      child: IconButton(
        tooltip: semanticLabel,
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        icon: Icon(icon),
      ),
    );
  }
}

class _NumberEntryDialog extends StatefulWidget {
  const _NumberEntryDialog({
    required this.label,
    required this.initial,
    required this.decimals,
  });

  final String label;
  final String initial;
  final bool decimals;

  @override
  State<_NumberEntryDialog> createState() => _NumberEntryDialogState();
}

class _NumberEntryDialogState extends State<_NumberEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initial.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            widget.decimals ? RegExp(r'[0-9.,]') : RegExp('[0-9]'),
          ),
        ],
        style: AppTypography.metricLarge,
        textAlign: TextAlign.center,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
