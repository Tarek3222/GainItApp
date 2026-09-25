import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../domain/entities/enums.dart';
import '../l10n/enum_labels.dart';

/// Target muscles as chips: main muscles filled, assisting ones outlined.
class MuscleChips extends StatelessWidget {
  const MuscleChips({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.dense = false,
  });

  final List<MuscleGroup> primary;
  final List<MuscleGroup> secondary;

  /// Smaller chips for list rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final density = dense ? VisualDensity.compact : VisualDensity.standard;
    // Main vs assisting is shown by fill colour; say it for screen readers.
    final separator = 'common.listSeparator'.tr();
    String names(List<MuscleGroup> muscles) =>
        muscles.map((m) => m.label).join(separator);
    final label = [
      if (primary.isNotEmpty)
        'muscleChips.main'.tr(namedArgs: {'muscles': names(primary)}),
      if (secondary.isNotEmpty)
        'muscleChips.also'.tr(namedArgs: {'muscles': names(secondary)}),
    ].join('. ');
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: _chips(scheme, density)),
    );
  }

  Widget _chips(ColorScheme scheme, VisualDensity density) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final muscle in primary)
          Chip(
            label: Text(muscle.label),
            visualDensity: density,
            backgroundColor: scheme.primary.withValues(alpha: 0.18),
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          ),
        for (final muscle in secondary)
          Chip(
            label: Text(muscle.label),
            visualDensity: density,
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }
}
