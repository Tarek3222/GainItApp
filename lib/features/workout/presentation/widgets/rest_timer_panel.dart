import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../cubits/rest_timer_cubit.dart';

/// Bottom rest-timer panel: countdown, pause/resume, ±15 s, skip.
/// Also forwards app lifecycle so the timer can alert while backgrounded.
class RestTimerPanel extends StatefulWidget {
  const RestTimerPanel({super.key});

  @override
  State<RestTimerPanel> createState() => _RestTimerPanelState();
}

class _RestTimerPanelState extends State<RestTimerPanel> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<RestTimerCubit>();
    _lifecycle = AppLifecycleListener(
      onHide: cubit.onAppBackgrounded,
      onShow: cubit.onAppResumed,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onFinished(RestTimerState state) {
    if (state.settings.vibrationEnabled) HapticFeedback.heavyImpact();
    if (state.settings.soundEnabled) SystemSound.play(SystemSoundType.alert);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RestTimerCubit, RestTimerState>(
      listenWhen: (prev, curr) =>
          prev.status != RestTimerStatus.finished &&
          curr.status == RestTimerStatus.finished,
      listener: (_, state) => _onFinished(state),
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.remaining.inSeconds != curr.remaining.inSeconds ||
          prev.total != curr.total,
      builder: (context, state) {
        return AnimatedSize(
          duration: AppDurations.medium,
          child: state.isVisible
              ? _TimerBody(state: state)
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

class _TimerBody extends StatelessWidget {
  const _TimerBody({required this.state});

  final RestTimerState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RestTimerCubit>();
    final theme = Theme.of(context);
    final finished = state.status == RestTimerStatus.finished;
    final paused = state.status == RestTimerStatus.paused;
    final accent = finished
        ? context.semanticColors.success
        : theme.colorScheme.primary;

    return Material(
      color: context.semanticColors.elevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: finished ? 1 : state.fraction,
                color: accent,
                backgroundColor: theme.colorScheme.surface,
                minHeight: 4,
                borderRadius: AppRadius.smAll,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (finished
                                  ? 'rest.over'
                                  : (paused ? 'rest.paused' : 'rest.label'))
                              .tr(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: accent,
                          ),
                        ),
                        Text(
                          finished
                              ? 'rest.go'.tr()
                              : Formatters.timer(
                                  // Round up so "0:00" only shows at the end.
                                  Duration(
                                    seconds:
                                        (state.remaining.inMilliseconds / 1000)
                                            .ceil(),
                                  ),
                                ),
                          style: AppTypography.metricLarge.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!finished) ...[
                    IconButton(
                      tooltip: 'rest.minus15'.tr(),
                      onPressed: () => cubit.adjust(-RestTimerCubit.adjustStep),
                      icon: const Text('−15'),
                    ),
                    IconButton(
                      tooltip: 'rest.plus15'.tr(),
                      onPressed: () => cubit.adjust(RestTimerCubit.adjustStep),
                      icon: const Text('+15'),
                    ),
                    IconButton.filledTonal(
                      tooltip: (paused ? 'rest.resume' : 'rest.pause').tr(),
                      onPressed: paused ? cubit.resume : cubit.pause,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    onPressed: finished ? cubit.dismiss : cubit.skip,
                    child: Text((finished ? 'rest.done' : 'rest.skip').tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
