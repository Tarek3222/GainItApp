import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.background,
    surface: AppColors.surface,
    elevated: AppColors.elevated,
    text: AppColors.text,
    muted: AppColors.mutedText,
    outline: AppColors.outline,
    semantic: AppSemanticColors.dark,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    elevated: AppColors.lightElevated,
    text: AppColors.lightText,
    muted: AppColors.lightMutedText,
    outline: AppColors.lightOutline,
    semantic: AppSemanticColors.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color elevated,
    required Color text,
    required Color muted,
    required Color outline,
    required AppSemanticColors semantic,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      error: semantic.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: elevated,
      surfaceContainerHighest: elevated,
      outline: outline,
      outlineVariant: outline,
    );
    final textTheme = AppTypography.textTheme(text, muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      // Material shared-axis (z) motion for opening a page. Scaled rather
      // than horizontal, which slides the same way in right-to-left text.
      // iOS keeps its native swipe-back transition. (This replaces Android's
      // predictive-back page animation.)
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ReducedMotionAware(
            SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.scaled,
              fillColor: background,
            ),
          ),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodySmall),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 4),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          foregroundColor: text,
          side: BorderSide(color: outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: semantic.danger),
        ),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        selectedColor: AppColors.primary.withValues(alpha: 0.25),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        labelStyle: textTheme.bodyMedium,
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      listTileTheme: ListTileThemeData(iconColor: muted),
    );
  }
}

/// Shows pages without motion when the phone asks for reduced motion. The
/// transition stays in the tree, settled, so toggling the setting never
/// resets the page below it.
class _ReducedMotionAware extends PageTransitionsBuilder {
  const _ReducedMotionAware(this._builder);

  final PageTransitionsBuilder _builder;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final still = MediaQuery.disableAnimationsOf(context);
    return _builder.buildTransitions(
      route,
      context,
      still ? kAlwaysCompleteAnimation : animation,
      still ? kAlwaysDismissedAnimation : secondaryAnimation,
      child,
    );
  }
}
