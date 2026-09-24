import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jumps the page's outermost scrollable to its end without a drag gesture,
/// so no wheel picker on the way is accidentally scrolled. Repeats because a
/// lazy list only knows its true extent once the tail has been built.
Future<void> scrollPageToEnd(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    if (position.pixels >= position.maxScrollExtent && i > 0) break;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

/// Taps each "Use …" confirm button on the wheel pickers, scrolling to it.
Future<void> confirmPickers(WidgetTester tester, List<String> labels) async {
  for (final label in labels) {
    final button = find.widgetWithText(TextButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

/// Jumps the page's outermost scrollable back to the top.
Future<void> scrollPageToTop(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}
