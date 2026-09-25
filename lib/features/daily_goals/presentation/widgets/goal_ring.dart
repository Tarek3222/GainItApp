import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';

/// Circular progress around the goal's icon; a check once it is reached.
/// The ring eases to its new value unless animations are turned off.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.fraction,
    required this.icon,
    required this.complete,
    this.size = 44,
  });

  final double fraction;
  final IconData icon;
  final bool complete;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = complete
        ? context.semanticColors.success
        : theme.colorScheme.primary;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction),
            duration: animate ? AppDurations.slow : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: context.semanticColors.elevated,
              ),
            ),
          ),
          Icon(complete ? Icons.check : icon, size: size * 0.45, color: color),
        ],
      ),
    );
  }
}
