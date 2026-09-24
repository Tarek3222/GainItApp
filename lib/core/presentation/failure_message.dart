import '../result/failures.dart';

extension FailureMessageX on Failure {
  /// User-facing text for a failure.
  String get userMessage => switch (this) {
    ValidationFailure(:final errors) =>
      errors.isEmpty ? 'Please check your input.' : errors.join('\n'),
    StorageFailure() => 'Could not read or save your data. Please try again.',
    NotFoundFailure() => 'This item no longer exists.',
    InvalidStateFailure(:final message) => message,
    UnexpectedFailure() => 'Something went wrong. Please try again.',
  };
}
