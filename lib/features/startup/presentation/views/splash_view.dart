import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
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

/// The logo gives a small pulse while the name rises in below. It sits in
/// the same place and size as the native launch screen's logo, so the
/// hand-over is seamless on iOS and Android before 12 (Android 12+ shows its
/// own round icon first).
class _Brand extends StatefulWidget {
  const _Brand();

  /// The native splash logo is 512 px drawn for 4x screens.
  static const logoSize = 128.0;

  @override
  State<_Brand> createState() => _BrandState();
}

class _BrandState extends State<_Brand> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _nameOpacity;
  late final Animation<Offset> _nameOffset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.6, curve: Curves.easeInOut),
          ),
        );
    final name = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
    );
    _nameOpacity = name;
    _nameOffset = Tween(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(name);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        // The name sits below the logo, outside the stack's own size.
        clipBehavior: Clip.none,
        children: [
          ScaleTransition(
            scale: _logoScale,
            child: Image.asset(
              AppInfo.logoAsset,
              width: _Brand.logoSize,
              height: _Brand.logoSize,
              excludeFromSemantics: true,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, _Brand.logoSize / 2 + AppSpacing.xl),
            child: FadeTransition(
              opacity: _nameOpacity,
              child: SlideTransition(
                position: _nameOffset,
                child: Text(
                  AppInfo.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
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
