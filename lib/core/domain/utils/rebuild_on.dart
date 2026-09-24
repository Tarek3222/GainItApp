import 'dart:async';

import '../../result/api_result.dart';

/// Maps [source] with [build], and re-runs [build] on the latest source value
/// whenever [triggers] fires. Useful when the output also depends on the
/// current time.
Stream<ApiResult<R>> rebuildOn<T, R>(
  Stream<ApiResult<T>> source,
  Stream<void> triggers,
  R Function(T data) build,
) {
  late final StreamController<ApiResult<R>> controller;
  StreamSubscription<ApiResult<T>>? sourceSub;
  StreamSubscription<void>? triggerSub;
  ApiResult<T>? latest;

  void emit() {
    final value = latest;
    if (value != null && !controller.isClosed) controller.add(value.map(build));
  }

  controller = StreamController<ApiResult<R>>(
    onListen: () {
      sourceSub = source.listen((value) {
        latest = value;
        emit();
      }, onError: controller.addError);
      triggerSub = triggers.listen((_) => emit());
    },
    onCancel: () async {
      await sourceSub?.cancel();
      await triggerSub?.cancel();
      unawaited(controller.close());
    },
  );
  return controller.stream;
}
