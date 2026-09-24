import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import '../errors/exceptions.dart';
import '../result/api_result.dart';
import '../result/failures.dart';

/// Maps anything thrown inside the data layer to a typed [Failure].
Failure mapStorageError(Object error) {
  return switch (error) {
    ValidationException(:final errors) => ValidationFailure(errors),
    NotFoundException(:final message) => NotFoundFailure(message),
    InvalidStateException(:final message) => InvalidStateFailure(message),
    HiveError() => const StorageFailure(),
    FileSystemException() => const StorageFailure(),
    _ => const UnexpectedFailure(),
  };
}

/// Runs a data-layer operation and converts errors at the boundary, so
/// exceptions never propagate to use cases or cubits.
Future<ApiResult<T>> guardStorage<T>(FutureOr<T> Function() body) async {
  try {
    return ApiSuccess(await body());
  } catch (error, stackTrace) {
    _debugLog(error, stackTrace);
    return ApiFailure(mapStorageError(error));
  }
}

/// Stream counterpart of [guardStorage]: errors become [ApiFailure] events.
Stream<ApiResult<T>> guardStream<T>(Stream<T> source) {
  return source.transform(
    StreamTransformer<T, ApiResult<T>>.fromHandlers(
      handleData: (data, sink) => sink.add(ApiSuccess(data)),
      handleError: (error, stackTrace, sink) {
        _debugLog(error, stackTrace);
        sink.add(ApiFailure(mapStorageError(error)));
      },
    ),
  );
}

void _debugLog(Object error, StackTrace stackTrace) {
  // Only error types/stack are logged — never user data values.
  if (kDebugMode && error is! ValidationException) {
    debugPrint('Storage error: ${error.runtimeType}\n$stackTrace');
  }
}

/// Throws [ValidationException] when [errors] is not empty.
void ensureValid(List<String> errors) {
  if (errors.isNotEmpty) throw ValidationException(errors);
}
