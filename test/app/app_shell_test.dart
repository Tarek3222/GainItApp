import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/router/app_shell.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/widgets/state_views.dart';
import 'package:gainit/features/program/presentation/widgets/exercise_config_sheet.dart';
import 'package:go_router/go_router.dart';

const _entry = ProgramExercise(
  id: 'pe',
  workoutDayId: 'day',
  exerciseId: 'ex',
  orderIndex: 0,
  workingSets: 3,
  repMin: 8,
  repMax: 12,
  restMinSeconds: 60,
  restMaxSeconds: 90,
  rirMin: 0,
  rirMax: 2,
  weightStep: 1,
);

/// A long page, with a text field to check each tab keeps its state.
class _TabPage extends StatelessWidget {
  const _TabPage(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      children: [
        TextField(key: ValueKey('$name field')),
        TextButton(
          onPressed: () => showMessage(context, '$name message'),
          child: Text('$name message button'),
        ),
        TextButton(
          onPressed: () => showExerciseConfigSheet(
            context,
            entry: _entry,
            exerciseName: 'Curl',
          ),
          child: Text('$name sheet button'),
        ),
        for (var i = 0; i < 20; i++)
          SizedBox(height: 80, child: Text('$name item $i')),
      ],
    ),
  );
}

void main() {
  Future<void> pumpShell(WidgetTester tester, {bool reduceMotion = false}) {
    StatefulShellBranch branch(String path) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (_, _) => _TabPage(path))],
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute(
          builder: (_, _, shell) => AppShell(shell: shell),
          navigatorContainerBuilder: (_, shell, children) =>
              FadingBranchContainer(
                currentIndex: shell.currentIndex,
                children: children,
              ),
          branches: [
            branch('/home'),
            branch('/plan'),
            branch('/progress'),
            branch('/profile'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduceMotion,
        ),
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
  }

  Rect barRect(WidgetTester tester) =>
      tester.getRect(find.byType(NavigationBar));

  testWidgets('the bar is frosted glass floating over the page', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    // The page runs under the bar rather than stopping above it.
    final page = tester.getRect(find.byType(ListView));
    expect(page.bottom, greaterThan(barRect(tester).top));
  });

  testWidgets('the end of a page scrolls clear of the bar', (tester) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();

    // A lazy list learns its full length while scrolling, so find the end
    // first, then push past it.
    await tester.scrollUntilVisible(
      find.text('/home item 19'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('/home item 19')).bottom,
      lessThanOrEqualTo(barRect(tester).top),
    );
  });

  testWidgets('messages show above the bar', (tester) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('/home message button'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(barRect(tester).top),
    );
  });

  testWidgets('a bottom sheet covers the bar, so its end can be tapped', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('/home sheet button'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    // The sheet is above the bar: nothing of the bar can take the tap.
    expect(
      tester
          .hitTestOnBinding(tester.getCenter(save))
          .path
          .any(
            (entry) =>
                entry.target == tester.renderObject(find.byType(NavigationBar)),
          ),
      isFalse,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(save, findsNothing);
  });

  testWidgets('switching tabs fades the new tab in and keeps the old one', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('/home field')), 'kept');

    await tester.tap(find.text('Plan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final fading = tester.widget<FadeThroughTransition>(
      find
          .ancestor(
            of: find.text('/plan item 0'),
            matching: find.byType(FadeThroughTransition),
          )
          .first,
    );
    expect(fading.animation.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text('/plan item 0'), findsOneWidget);
    expect(find.text('/home item 0'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('kept'), findsOneWidget);
  });

  testWidgets('with reduced motion tabs switch at once', (tester) async {
    await pumpShell(tester, reduceMotion: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan'));
    await tester.pump();

    final fading = tester.widget<FadeThroughTransition>(
      find
          .ancestor(
            of: find.text('/plan item 0'),
            matching: find.byType(FadeThroughTransition),
          )
          .first,
    );
    expect(fading.animation.value, 1);
  });
}
