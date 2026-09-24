import 'package:flutter/material.dart';

/// Raw palette from the GainIt design direction (spec §17).
///
/// Widgets should read colors from `Theme.of(context).colorScheme` or
/// [AppSemanticColors]; these constants exist to build the themes.
abstract final class AppColors {
  static const background = Color(0xFF0D0F12);
  static const surface = Color(0xFF171A1F);
  static const elevated = Color(0xFF20242B);
  static const primary = Color(0xFFC8102E);
  static const text = Color(0xFFF5F5F5);
  static const mutedText = Color(0xFF9EA4AD);
  static const success = Color(0xFF2EBD85);
  static const warning = Color(0xFFF2B84B);
  static const danger = Color(0xFFE05252);
  static const outline = Color(0xFF2C313A);

  static const lightBackground = Color(0xFFF6F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFECEEF2);
  static const lightText = Color(0xFF111418);
  static const lightMutedText = Color(0xFF5C636E);
  static const lightOutline = Color(0xFFD5D9E0);
}

/// Semantic colors that Material's [ColorScheme] has no slot for.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.mutedText,
    required this.elevated,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color mutedText;
  final Color elevated;

  static const dark = AppSemanticColors(
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    mutedText: AppColors.mutedText,
    elevated: AppColors.elevated,
  );

  static const light = AppSemanticColors(
    success: Color(0xFF1E9E6C),
    warning: Color(0xFFB9811A),
    danger: Color(0xFFC53A3A),
    mutedText: AppColors.lightMutedText,
    elevated: AppColors.lightElevated,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? mutedText,
    Color? elevated,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      mutedText: mutedText ?? this.mutedText,
      elevated: elevated ?? this.elevated,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;
}
