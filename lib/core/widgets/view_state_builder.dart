import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/view_state.dart';
import 'state_views.dart';

/// Renders loading / error automatically and delegates the loaded state.
class ViewStateBuilder<C extends Cubit<ViewState<T>>, T>
    extends StatelessWidget {
  const ViewStateBuilder({
    super.key,
    required this.builder,
    this.onRetry,
    this.errorBuilder,
  });

  final Widget Function(BuildContext context, T data) builder;
  final void Function(C cubit)? onRetry;

  /// Replaces the default full-screen error, e.g. to keep independent
  /// content visible. Receives the message and the retry action.
  final Widget Function(
    BuildContext context,
    String message,
    VoidCallback? retry,
  )?
  errorBuilder;

  Widget _error(BuildContext context, String message) {
    final retry = onRetry == null ? null : () => onRetry!(context.read<C>());
    return errorBuilder?.call(context, message, retry) ??
        ErrorView(message: message, onRetry: retry);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<C, ViewState<T>>(
      builder: (context, state) => switch (state) {
        ViewLoading<T>() => const LoadingView(),
        ViewError<T>(:final message) => _error(context, message),
        ViewLoaded<T>(:final data) => builder(context, data),
      },
    );
  }
}
