import 'dart:async';

import '../../result/api_result.dart';

/// Emits [combine] of the latest values of [first] and [second] once both
/// have emitted, and again whenever either changes. A failure from either
/// stream is forwarded as the combined result.
Stream<ApiResult<R>> combineResults<A, B, R>(
  Stream<ApiResult<A>> first,
  Stream<ApiResult<B>> second,
  R Function(A a, B b) combine,
) {
  late final StreamController<ApiResult<R>> controller;
  StreamSubscription<ApiResult<A>>? firstSub;
  StreamSubscription<ApiResult<B>>? secondSub;
  ApiResult<A>? latestA;
  ApiResult<B>? latestB;

  void emit() {
    final a = latestA;
    final b = latestB;
    if (a == null || b == null || controller.isClosed) return;
    controller.add(switch ((a, b)) {
      (ApiFailure(:final failure), _) => ApiFailure(failure),
      (_, ApiFailure(:final failure)) => ApiFailure(failure),
      (ApiSuccess(data: final va), ApiSuccess(data: final vb)) => ApiSuccess(
        combine(va, vb),
      ),
    });
  }

  controller = StreamController<ApiResult<R>>(
    onListen: () {
      firstSub = first.listen((value) {
        latestA = value;
        emit();
      }, onError: controller.addError);
      secondSub = second.listen((value) {
        latestB = value;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
      unawaited(controller.close());
    },
  );
  return controller.stream;
}
