import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/widgets/measure_wheel_picker.dart';

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
            BodyWeightPicker(
              weightKg: _kg,
              system: context.units.system,
              onChanged: (kg) => setState(() => _kg = kg),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_kg),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
