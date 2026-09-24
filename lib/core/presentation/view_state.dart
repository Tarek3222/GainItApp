import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../result/api_result.dart';
import 'failure_message.dart';

/// Shared loading / loaded / error state for read-mostly screens.
sealed class ViewState<T> extends Equatable {
  const ViewState();

  @override
  List<Object?> get props => [];
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

final class ViewLoaded<T> extends ViewState<T> {
  const ViewLoaded(this.data);

  final T data;

  @override
  List<Object?> get props => [data];
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Base cubit that mirrors a reactive use case into [ViewState].
abstract class StreamViewCubit<T> extends Cubit<ViewState<T>> {
  StreamViewCubit() : super(ViewLoading<T>());

  StreamSubscription<ApiResult<T>>? _subscription;

  /// The use-case stream to observe.
  Stream<ApiResult<T>> source();

  void start() {
    unawaited(_subscription?.cancel());
    if (state is! ViewLoaded<T>) emit(ViewLoading<T>());
    _subscription = source().listen((result) {
      if (isClosed) return;
      emit(
        result.fold(
          (failure) => ViewError<T>(failure.userMessage),
          ViewLoaded<T>.new,
        ),
      );
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

/// Base cubit for screens that load once from a future use case.
abstract class FutureViewCubit<T> extends Cubit<ViewState<T>> {
  FutureViewCubit() : super(ViewLoading<T>());

  Future<ApiResult<T>> fetch();

  Future<void> load() async {
    emit(ViewLoading<T>());
    final result = await fetch();
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => ViewError<T>(failure.userMessage),
        ViewLoaded<T>.new,
      ),
    );
  }
}
