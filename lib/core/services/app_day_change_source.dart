import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/services/day_change_source.dart';
import 'clock.dart';

/// Fires just after local midnight and whenever the app resumes.
/// Needs an initialised `WidgetsBinding` (create it after `runApp` setup).
class AppDayChangeSource implements DayChangeSource {
  AppDayChangeSource(this._clock) {
    _lifecycle = AppLifecycleListener(onResume: _emit);
    _scheduleMidnight();
  }

  final Clock _clock;
  final _controller = StreamController<void>.broadcast();
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  @override
  Stream<void> get changes => _controller.stream;

  void _emit() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void _scheduleMidnight() {
    final now = _clock.now();
    // A few seconds past midnight so "today" has definitely rolled over.
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _timer = Timer(next.difference(now), () {
      _emit();
      _scheduleMidnight();
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _lifecycle.dispose();
    await _controller.close();
  }
}
