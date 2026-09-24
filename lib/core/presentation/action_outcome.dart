import '../result/api_result.dart';
import 'failure_message.dart';

/// Result of a one-off user action (start workout, save weight…) returned to
/// the view so it can navigate or show feedback.
sealed class ActionOutcome<T> {
  const ActionOutcome();

  static ActionOutcome<T> from<T>(ApiResult<T> result) => result.fold(
    (failure) => ActionFailed<T>(failure.userMessage),
    ActionDone<T>.new,
  );
}

final class ActionDone<T> extends ActionOutcome<T> {
  const ActionDone(this.value);

  final T value;
}

final class ActionFailed<T> extends ActionOutcome<T> {
  const ActionFailed(this.message);

  final String message;
}
