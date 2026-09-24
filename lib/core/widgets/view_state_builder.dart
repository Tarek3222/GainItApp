import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/view_state.dart';
import 'state_views.dart';

/// Renders loading / error automatically and delegates the loaded state.
class ViewStateBuilder<C extends Cubit<ViewState<T>>, T>
    extends StatelessWidget {
  const ViewStateBuilder({super.key, required this.builder, this.onRetry});

  final Widget Function(BuildContext context, T data) builder;
  final void Function(C cubit)? onRetry;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<C, ViewState<T>>(
      builder: (context, state) => switch (state) {
        ViewLoading<T>() => const LoadingView(),
        ViewError<T>(:final message) => ErrorView(
          message: message,
          onRetry: onRetry == null ? null : () => onRetry!(context.read<C>()),
        ),
        ViewLoaded<T>(:final data) => builder(context, data),
      },
    );
  }
}
