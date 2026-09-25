import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Small animations shared by all screens. With reduced motion (the phone's
/// setting) they show the widget as it is, keeping the same widgets in the
/// tree so turning the setting on or off never resets what is below.
///
/// Built on implicit animations (tickers), never timers, so nothing is left
/// pending when a screen closes early.
extension MotionX on Widget {
  /// A quick springy scale, for something that just happened (a set
  /// logged). Pass [enabled] false to show it without the pop.
  Widget pop(BuildContext context, {bool enabled = true}) {
    final still = !enabled || MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0.4, end: 1),
      duration: AppDurations.slow,
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: this,
    );
  }

  /// A short bump when a value changes. Give it a [key] built from the value
  /// so the bump plays again on every change.
  Widget bump(BuildContext context, {required Key key}) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: still ? 1 : 1.12, end: 1),
      duration: AppDurations.medium,
      curve: Curves.easeOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: this,
    );
  }
}

/// Fades [child] in and lifts it slightly into place; [index] staggers the
/// items of a list (only the first few wait, so long lists don't lag).
Widget _entrance(int index, Widget child) {
  final delay = AppDurations.stagger * math.min(index, _maxStaggered);
  final total = delay + AppDurations.slow;
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: total,
    curve: Interval(
      delay.inMicroseconds / total.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
    builder: (_, t, child) => Opacity(
      opacity: t,
      child: FractionalTranslation(
        translation: Offset(0, (1 - t) * 0.06),
        child: child,
      ),
    ),
    child: child,
  );
}

const _maxStaggered = 6;

/// Fades in, one after another, the widgets that appear together when a
/// screen opens. Widgets built later (scrolled into view, or added after the
/// first frame) just appear, so scrolling never replays the animation.
class EntranceGroup extends StatefulWidget {
  const EntranceGroup({super.key, required this.builder});

  /// Builds the content; wrap each item with the given `item` function.
  final Widget Function(
    BuildContext context,
    Widget Function(int index, Widget child) item,
  )
  builder;

  @override
  State<EntranceGroup> createState() => _EntranceGroupState();
}

class _EntranceGroupState extends State<EntranceGroup> {
  bool _open = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open = false);
  }

  Widget _item(int index, Widget child) => _EntranceItem(
    key: child.key == null ? null : ValueKey(child.key),
    index: index,
    animate: () => _open,
    child: child,
  );

  @override
  Widget build(BuildContext context) => widget.builder(context, _item);
}

class _EntranceItem extends StatefulWidget {
  const _EntranceItem({
    super.key,
    required this.index,
    required this.animate,
    required this.child,
  });

  final int index;
  final bool Function() animate;
  final Widget child;

  @override
  State<_EntranceItem> createState() => _EntranceItemState();
}

class _EntranceItemState extends State<_EntranceItem> {
  bool? _animate;

  @override
  Widget build(BuildContext context) {
    // Decided once, so the widget tree below never changes shape.
    final animate = _animate ??=
        widget.animate() && !MediaQuery.disableAnimationsOf(context);
    return animate ? _entrance(widget.index, widget.child) : widget.child;
  }
}
