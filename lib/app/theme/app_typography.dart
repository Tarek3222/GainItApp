import 'package:flutter/material.dart';

/// Typography tokens. Poppins is bundled for headings and key numbers;
/// body text falls back to the platform font for readability. Neither has
/// Arabic letters, so every style falls back to the bundled Cairo font.
abstract final class AppTypography {
  static const headingFamily = 'Poppins';
  static const arabicFamily = 'Cairo';
  static const _fallback = [arabicFamily];

  static TextTheme textTheme(Color text, Color muted) {
    const base = Typography.englishLike2021;
    return base
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          displaySmall: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ).copyWith(color: text),
          headlineMedium: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ).copyWith(color: text),
          headlineSmall: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ).copyWith(color: text),
          titleLarge: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ).copyWith(color: text),
          titleMedium: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ).copyWith(color: text),
          titleSmall: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ).copyWith(color: text),
          bodyLarge: TextStyle(fontSize: 16, color: text),
          bodyMedium: TextStyle(fontSize: 14, color: text),
          bodySmall: TextStyle(fontSize: 12, color: muted),
          labelLarge: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ).copyWith(color: text),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: muted,
          ),
        )
        .apply(fontFamilyFallback: _fallback);
  }

  /// Large numerals for weight / reps in the active workout.
  static const TextStyle metricLarge = TextStyle(
    fontFamily: headingFamily,
    fontFamilyFallback: _fallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricMedium = TextStyle(
    fontFamily: headingFamily,
    fontFamilyFallback: _fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle timer = TextStyle(
    fontFamily: headingFamily,
    fontFamilyFallback: _fallback,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
