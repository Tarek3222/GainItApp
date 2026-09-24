import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/enums.dart';
import '../../domain/usecases/watch_unit_system_use_case.dart';
import '../../result/api_result.dart';

/// App-wide display unit. Falls back to metric (the storage unit) when the
/// preference cannot be read, so screens always have a usable value.
class UnitsCubit extends Cubit<UnitSystem> {
  UnitsCubit(this._watch) : super(UnitSystem.metric);

  final WatchUnitSystemUseCase _watch;
  StreamSubscription<ApiResult<UnitSystem>>? _subscription;

  void start() {
    unawaited(_subscription?.cancel());
    _subscription = _watch().listen((result) {
      if (isClosed) return;
      switch (result) {
        case ApiSuccess(:final data):
          emit(data);
        case ApiFailure(:final failure):
          // Keep the last known unit; storage errors surface elsewhere.
          if (kDebugMode) debugPrint('UnitsCubit: ${failure.message}');
      }
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
