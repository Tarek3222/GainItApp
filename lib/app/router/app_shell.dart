import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_tokens.dart';

/// Bottom navigation: Home · Plan · Progress · Profile (spec §16).
///
/// The bar floats over the content as frosted glass; pages scroll under it
/// (`extendBody`) and pad their ends by the space it covers.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _GlassNavigationBar(
        selectedIndex: shell.currentIndex,
        onSelected: (index) {
          HapticFeedback.selectionClick();
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
      ),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _radius = BorderRadius.all(Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm + bottomInset,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.72),
                  borderRadius: _radius,
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                // The bar already sits above the system inset.
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: NavigationBar(
                    height: 64,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home),
                        label: 'nav.home'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.calendar_view_week_outlined),
                        selectedIcon: const Icon(Icons.calendar_view_week),
                        label: 'nav.plan'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.show_chart),
                        label: 'nav.progress'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.person_outline),
                        selectedIcon: const Icon(Icons.person),
                        label: 'nav.profile'.tr(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds the tab pages, keeping each one's state like an [IndexedStack],
/// and fades through to the tab that was just picked.
class FadingBranchContainer extends StatefulWidget {
  const FadingBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadingBranchContainer> createState() => _FadingBranchContainerState();
}

class _FadingBranchContainerState extends State<FadingBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(FadingBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return IndexedStack(
      index: widget.currentIndex,
      children: [
        for (final (i, child) in widget.children.indexed)
          // Same widgets for every tab and state, so pages keep their state.
          Offstage(
            offstage: i != widget.currentIndex,
            child: TickerMode(
              enabled: i == widget.currentIndex,
              child: FadeThroughTransition(
                animation: i == widget.currentIndex
                    ? _controller
                    : kAlwaysCompleteAnimation,
                secondaryAnimation: kAlwaysDismissedAnimation,
                fillColor: background,
                child: child,
              ),
            ),
          ),
      ],
    );
  }
}
