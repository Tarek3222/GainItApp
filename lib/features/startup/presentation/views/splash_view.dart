import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_info.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/startup_status.dart';
import '../cubits/splash_cubit.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SplashCubit, SplashState>(
      listener: (context, state) {
        switch (state) {
          case SplashNeedsOnboarding():
            context.go(RoutePaths.onboarding);
          case SplashReady():
            context.go(RoutePaths.home);
          default:
            break;
        }
      },
      builder: (context, state) => Scaffold(
        body: switch (state) {
          SplashError(:final message) => ErrorView(
            message: message,
            onRetry: context.read<SplashCubit>().check,
          ),
          SplashInterruptedWorkout(:final workout) => _ResumePrompt(
            workout: workout,
          ),
          _ => const _Brand(),
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppInfo.name,
        style: AppTypography.timer.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ResumePrompt extends StatelessWidget {
  const _ResumePrompt({required this.workout});

  final InterruptedWorkout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<SplashCubit>();
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'splash.resumeTitle'.tr(),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    seedName(workout.workoutName),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'splash.setsCompleted'.tr(
                      namedArgs: {
                        'done': '${workout.completedSets}',
                        'total': '${workout.totalSets}',
                      },
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.semanticColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () =>
                        context.go(RoutePaths.workout(workout.sessionId)),
                    child: Text('splash.resume'.tr()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => cubit.discard(workout.sessionId),
                    child: Text('splash.discard'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
