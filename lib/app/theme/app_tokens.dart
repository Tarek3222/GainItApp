import 'package:flutter/material.dart';

/// Spacing scale. Never scatter raw paddings through widgets (spec §18).
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Horizontal page gutter.
  static const page = md;

  /// Max width of scrollable content on tablets / large screens.
  static const maxContentWidth = 640.0;

  /// Minimum size of touch targets in the active workout (thumb friendly).
  static const minTouchTarget = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  /// Delay between items of a list that animates in one after another.
  static const stagger = Duration(milliseconds: 40);
}

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
