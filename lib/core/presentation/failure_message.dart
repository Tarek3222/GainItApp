import 'package:easy_localization/easy_localization.dart';

import '../domain/validation/validators.dart';
import '../l10n/seed_names.dart';
import '../result/failures.dart';

extension FailureMessageX on Failure {
  /// User-facing text for a failure, in the current language.
  String get userMessage => switch (this) {
    ValidationFailure(:final errors) =>
      errors.isEmpty
          ? 'errors.checkInput'.tr()
          : errors.map(translateMessage).join('\n'),
    StorageFailure() => 'errors.storage'.tr(),
    NotFoundFailure() => 'errors.notFound'.tr(),
    InvalidStateFailure(:final message, :final args) => translateMessage(
      message,
      args,
    ),
    UnexpectedFailure() => 'errors.unexpected'.tr(),
  };
}

/// Translates a message key from the domain, filling in validation limits
/// and [args]. Built-in names in [args] are translated too. Text that is
/// not a key is returned unchanged.
String translateMessage(String key, [Map<String, String> args = const {}]) =>
    key.tr(
      namedArgs: {
        ...Validators.messageArgs,
        for (final MapEntry(:key, :value) in args.entries) key: seedName(value),
      },
    );
