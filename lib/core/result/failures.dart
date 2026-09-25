import 'package:equatable/equatable.dart';

/// Typed failures that cross from the data layer to presentation.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Reading or writing local storage failed.
final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Could not access local data.']);
}

/// Input rejected by a validator before it reached storage. [errors] are
/// translation keys.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.errors) : super('Invalid input.');

  final List<String> errors;

  @override
  List<Object?> get props => [message, errors];
}

/// A referenced record does not exist (e.g. a deleted session).
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'The requested data was not found.']);
}

/// The requested operation is not allowed in the current state
/// (e.g. logging a set on a finished workout). [message] is a translation
/// key; [args] fill its `{placeholders}`.
final class InvalidStateFailure extends Failure {
  const InvalidStateFailure(super.message, {this.args = const {}});

  final Map<String, String> args;

  @override
  List<Object?> get props => [message, args];
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong.']);
}
