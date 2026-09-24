import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/number_stepper.dart';

/// Bottom sheet to log a weigh-in. Returns the entered kg, or `null`.
Future<double?> showLogWeightSheet(BuildContext context, {double? initialKg}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LogWeightSheet(initialKg: initialKg ?? 70),
  );
}

class _LogWeightSheet extends StatefulWidget {
  const _LogWeightSheet({required this.initialKg});

  final double initialKg;

  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  late double _kg = widget.initialKg;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log body weight',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            NumberStepper(
              label: 'kg',
              value: _kg,
              step: 0.1,
              min: 20,
              max: 400,
              decimals: true,
              format: (v) =>
                  Formatters.weight(double.parse(v.toStringAsFixed(1))),
              onChanged: (v) => setState(() => _kg = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(double.parse(_kg.toStringAsFixed(1))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
