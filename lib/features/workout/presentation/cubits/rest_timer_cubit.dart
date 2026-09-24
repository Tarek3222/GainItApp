import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/services/clock.dart';
import '../../domain/usecases/rest_timer_use_cases.dart';

part 'rest_timer_state.dart';

/// Rest timer driven by an absolute end time. The periodic tick only
/// re-reads the clock, so the countdown stays correct across rebuilds,
/// dropped frames and time spent in the background (spec §4.E).
class RestTimerCubit extends Cubit<RestTimerState> {
  RestTimerCubit({
    required this._clock,
    required this._getSettings,
    required this._scheduleAlert,
    required this._cancelAlert,
    required this._prepareAlerts,
    this.tickInterval = const Duration(milliseconds: 250),
  }) : super(const RestTimerState());

  static const adjustStep = Duration(seconds: 15);

  final Clock _clock;
  final GetRestTimerSettingsUseCase _getSettings;
  final ScheduleRestAlertUseCase _scheduleAlert;
  final CancelRestAlertUseCase _cancelAlert;
  final PrepareRestAlertsUseCase _prepareAlerts;
  final Duration tickInterval;

  Timer? _ticker;
  bool _inBackground = false;

  /// Loads timer preferences and, when background alerts are on, asks for
  /// notification permission up front — never at the moment the user leaves
  /// the app.
  Future<void> loadSettings() async {
    final result = await _getSettings();
    if (isClosed) return;
    if (result case ApiSuccess(:final data)) {
      emit(state.copyWith(settings: data));
      if (data.restAlertsEnabled) await _prepareAlerts();
    }
  }

  void start({required int seconds, required String exerciseName}) {
    if (seconds <= 0) {
      stop();
      return;
    }
    final total = Duration(seconds: seconds);
    emit(
      state.copyWith(
        status: RestTimerStatus.running,
        total: total,
        remaining: total,
        endsAt: _clock.now().add(total),
        exerciseName: exerciseName,
      ),
    );
    _startTicker();
  }

  void pause() {
    if (state.status != RestTimerStatus.running) return;
    _stopTicker();
    emit(
      state.copyWith(status: RestTimerStatus.paused, remaining: _remaining()),
    );
    unawaited(_cancelAlert());
  }

  void resume() {
    if (state.status != RestTimerStatus.paused) return;
    emit(
      state.copyWith(
        status: RestTimerStatus.running,
        endsAt: _clock.now().add(state.remaining),
      ),
    );
    _startTicker();
    if (_inBackground) _scheduleInBackground();
  }

  /// +15 s / −15 s. Never goes below zero.
  void adjust(Duration delta) {
    switch (state.status) {
      case RestTimerStatus.running:
        final endsAt = state.endsAt!.add(delta);
        final remaining = endsAt.difference(_clock.now());
        emit(
          state.copyWith(
            endsAt: endsAt,
            remaining: remaining.isNegative ? Duration.zero : remaining,
            total: _max(state.total + delta, remaining),
          ),
        );
        tick();
      case RestTimerStatus.paused:
        final remaining = state.remaining + delta;
        emit(
          state.copyWith(
            remaining: remaining.isNegative ? Duration.zero : remaining,
            total: _max(state.total + delta, remaining),
          ),
        );
      case RestTimerStatus.idle || RestTimerStatus.finished:
        return;
    }
  }

  void skip() => stop();

  void stop() {
    _stopTicker();
    emit(RestTimerState(settings: state.settings));
    unawaited(_cancelAlert());
  }

  /// Hides the "rest over" banner after it was acknowledged.
  void dismiss() {
    if (state.status == RestTimerStatus.finished) stop();
  }

  void onAppBackgrounded() {
    _inBackground = true;
    if (state.status == RestTimerStatus.running) _scheduleInBackground();
  }

  void onAppResumed() {
    _inBackground = false;
    unawaited(_cancelAlert());
    tick();
  }

  void _scheduleInBackground() {
    if (!state.settings.restAlertsEnabled) return;
    unawaited(
      _scheduleAlert(endsAt: state.endsAt!, exerciseName: state.exerciseName),
    );
  }

  @visibleForTesting
  void tick() {
    if (state.status != RestTimerStatus.running) return;
    final remaining = _remaining();
    if (remaining <= Duration.zero) {
      _stopTicker();
      emit(
        state.copyWith(
          status: RestTimerStatus.finished,
          remaining: Duration.zero,
        ),
      );
    } else if (remaining.inSeconds != state.remaining.inSeconds ||
        remaining > state.remaining) {
      emit(state.copyWith(remaining: remaining));
    }
  }

  Duration _remaining() {
    final endsAt = state.endsAt;
    if (endsAt == null) return state.remaining;
    final remaining = endsAt.difference(_clock.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static Duration _max(Duration a, Duration b) => a > b ? a : b;

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(tickInterval, (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Future<void> close() {
    _stopTicker();
    // Leaving the workout must not leave a pending "rest over" alert behind.
    unawaited(_cancelAlert());
    return super.close();
  }
}
