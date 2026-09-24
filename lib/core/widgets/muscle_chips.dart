import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../domain/entities/enums.dart';

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
    final label = [
      if (primary.isNotEmpty)
        'Main muscles: ${primary.map((m) => m.label).join(', ')}',
      if (secondary.isNotEmpty)
        'Also works: ${secondary.map((m) => m.label).join(', ')}',
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
