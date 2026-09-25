import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/widgets/state_views.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required List<Widget> children,
    bool reduceMotion = false,
    double bottomInset = 0,
  }) {
    // The real test screen, so positions can be checked against it.
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: reduceMotion,
            padding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(body: PageBody(children: children)),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, String text) {
    final opacities = tester.widgetList<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
    );
    return opacities.fold(1.0, (value, o) => value * o.opacity);
  }

  testWidgets('page items fade in one after another', (tester) async {
    await pumpPage(tester, children: const [Text('first'), Text('second')]);

    await tester.pump(const Duration(milliseconds: 20));
    expect(opacityOf(tester, 'first'), greaterThan(0));
    expect(opacityOf(tester, 'second'), 0);

    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'first'), 1);
    expect(opacityOf(tester, 'second'), 1);
  });

  testWidgets('items built after the page opened appear without animating', (
    tester,
  ) async {
    await pumpPage(
      tester,
      children: [
        for (var i = 0; i < 40; i++)
          SizedBox(height: 100, child: Text('item $i')),
      ],
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('item 39'), 500);
    await tester.pump();

    expect(opacityOf(tester, 'item 39'), 1);
  });

  testWidgets('reduced motion shows items at once', (tester) async {
    await pumpPage(tester, reduceMotion: true, children: const [Text('first')]);

    expect(
      find.ancestor(
        of: find.text('first'),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
  });

  testWidgets('turning reduced motion on keeps what is on the page', (
    tester,
  ) async {
    const page = Scaffold(
      body: PageBody(children: [TextField(key: ValueKey('field'))]),
    );
    Widget app({required bool reduceMotion}) => MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: page,
      ),
    );
    await tester.pumpWidget(app(reduceMotion: false));
    await tester.enterText(find.byKey(const ValueKey('field')), 'kept');
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pumpAndSettle();

    expect(find.text('kept'), findsOneWidget);
  });

  testWidgets('the page pads its end for bars drawn over it', (tester) async {
    await pumpPage(
      tester,
      bottomInset: 90,
      children: [
        for (var i = 0; i < 20; i++)
          SizedBox(height: 100, child: Text('item $i')),
      ],
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('item 19'), 500);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('item 19')).bottom, lessThan(800 - 90));
  });
}
