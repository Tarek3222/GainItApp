import 'failures.dart';

/// Result of any repository / use-case operation (CLAUDE.md B5).
sealed class ApiResult<T> {
  const ApiResult();

  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T data) onSuccess,
  ) {
    return switch (this) {
      ApiSuccess<T>(:final data) => onSuccess(data),
      ApiFailure<T>(:final failure) => onFailure(failure),
    };
  }

  /// Transforms the success value, keeping failures untouched.
  ApiResult<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      ApiSuccess<T>(:final data) => ApiSuccess(transform(data)),
      ApiFailure<T>(:final failure) => ApiFailure(failure),
    };
  }

  bool get isSuccess => this is ApiSuccess<T>;
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);

  final T data;

  @override
  bool operator ==(Object other) =>
      other is ApiSuccess<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'ApiSuccess($data)';
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      other is ApiFailure<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'ApiFailure($failure)';
}

/// Convenience for use cases that only report completion.
typedef VoidResult = ApiResult<void>;

const VoidResult voidSuccess = ApiSuccess<void>(null);
