/// Exceptions thrown inside the data layer and converted to `Failure`s at the
/// repository boundary by `guardStorage`. They never reach presentation.
final class ValidationException implements Exception {
  const ValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'ValidationException(${errors.join('; ')})';
}

final class NotFoundException implements Exception {
  const NotFoundException(this.message);

  final String message;

  @override
  String toString() => 'NotFoundException($message)';
}

final class InvalidStateException implements Exception {
  const InvalidStateException(this.message);

  final String message;

  @override
  String toString() => 'InvalidStateException($message)';
}
