import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/domain/entities/daily_goal.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/services/step_counter.dart';
import 'package:gainit/core/presentation/action_outcome.dart';
import 'package:gainit/core/presentation/units/unit_format.dart';
import 'package:gainit/core/presentation/view_state.dart';
import 'package:gainit/features/daily_goals/domain/entities/daily_goal_entities.dart';
import 'package:gainit/features/daily_goals/presentation/cubits/daily_goal_cubits.dart';
import 'package:gainit/features/daily_goals/presentation/views/daily_goals_view.dart';
import 'package:gainit/features/daily_goals/presentation/widgets/todays_progress_card.dart';
import 'package:mocktail/mocktail.dart';

class _MockTodayGoalsCubit extends MockCubit<ViewState<TodayGoals>>
    implements TodayGoalsCubit {}

class _MockDailyGoalsCubit extends MockCubit<ViewState<List<DailyGoal>>>
    implements DailyGoalsCubit {}

final _water = DailyGoal(
  id: 'water',
  type: DailyGoalType.water,
  target: 3000,
  sortOrder: 0,
  createdAt: DateTime(2026),
);

final _steps = DailyGoal(
  id: 'steps',
  type: DailyGoalType.steps,
  target: 10000,
  sortOrder: 1,
  createdAt: DateTime(2026),
);

final _read = DailyGoal(
  id: 'read',
  type: DailyGoalType.custom,
  target: 20,
  sortOrder: 2,
  createdAt: DateTime(2026),
  title: 'Read',
  unit: 'pages',
  increment: 5,
);

Widget _app(Widget child, {UnitSystem units = UnitSystem.metric}) =>
    MaterialApp(
      theme: AppTheme.dark,
      builder: (_, child) => UnitScope(system: units, child: child!),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(
      const GoalInput(type: DailyGoalType.custom, target: 1),
    );
    registerFallbackValue(_water);
  });

  group('TodaysProgressCard', () {
    late _MockTodayGoalsCubit cubit;

    Future<void> pump(
      WidgetTester tester,
      TodayGoals today, {
      UnitSystem units = UnitSystem.metric,
    }) async {
      when(() => cubit.state).thenReturn(ViewLoaded(today));
      await tester.pumpWidget(
        _app(
          BlocProvider<TodayGoalsCubit>.value(
            value: cubit,
            child: const TodaysProgressCard(),
          ),
          units: units,
        ),
      );
    }

    setUp(() {
      cubit = _MockTodayGoalsCubit();
      // Everything asked for is applied.
      when(() => cubit.addProgress(any(), any())).thenAnswer(
        (call) async => ActionDone(call.positionalArguments[1] as double),
      );
    });

    testWidgets('shows each goal against its target', (tester) async {
      await pump(
        tester,
        TodayGoals(
          goals: [
            GoalProgress(goal: _water, amount: 1250),
            GoalProgress(goal: _steps, amount: 10250, sensorAmount: 10250),
            GoalProgress(goal: _read, amount: 5),
          ],
          stepStatus: StepStatus.active,
        ),
      );

      expect(find.text('TODAY’S PROGRESS'), findsOneWidget);
      expect(find.text('1 of 3 goals reached'), findsOneWidget);
      expect(find.text('1.25 / 3 L'), findsOneWidget);
      expect(find.text('10,250 / 10,000 steps'), findsOneWidget);
      expect(find.text('5 / 20 pages'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('water is shown in fl oz for imperial users', (tester) async {
      await pump(
        tester,
        TodayGoals(
          goals: [GoalProgress(goal: _water, amount: 1000)],
          stepStatus: StepStatus.active,
        ),
        units: UnitSystem.imperial,
      );

      expect(find.text('33.8 / 101.4 fl oz'), findsOneWidget);
      expect(find.text('+8 fl oz'), findsOneWidget);
    });

    testWidgets('a quick add logs a glass and can be undone', (tester) async {
      await pump(
        tester,
        TodayGoals(
          goals: [GoalProgress(goal: _water, amount: 1250)],
          stepStatus: StepStatus.active,
        ),
      );

      await tester.tap(find.text('+250 ml'));
      await tester.pumpAndSettle();

      verify(() => cubit.addProgress('water', 250)).called(1);
      expect(find.text('Added 250 ml'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();

      verify(() => cubit.addProgress('water', -250)).called(1);
    });

    testWidgets('the undo bar goes away by itself', (tester) async {
      await pump(
        tester,
        TodayGoals(
          goals: [GoalProgress(goal: _water, amount: 1250)],
          stepStatus: StepStatus.active,
        ),
      );

      await tester.tap(find.text('+250 ml'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Added 250 ml'), findsNothing);
    });

    testWidgets('a custom goal adds its own quick-add amount', (tester) async {
      await pump(
        tester,
        TodayGoals(
          goals: [GoalProgress(goal: _read, amount: 5)],
          stepStatus: StepStatus.active,
        ),
      );

      await tester.tap(find.text('+5'));
      await tester.pump();

      verify(() => cubit.addProgress('read', 5)).called(1);
    });

    testWidgets('steps without permission offer to turn counting on', (
      tester,
    ) async {
      when(
        () => cubit.enableStepCounting(),
      ).thenAnswer((_) async => StepAccess.granted);
      await pump(
        tester,
        TodayGoals(
          goals: [GoalProgress(goal: _steps, amount: 0)],
          stepStatus: StepStatus.needsPermission,
        ),
      );

      expect(find.text('Allow step counting to track steps'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pump();

      verify(() => cubit.enableStepCounting()).called(1);
    });

    testWidgets('steps can be added by hand from the log sheet', (
      tester,
    ) async {
      await pump(
        tester,
        TodayGoals(
          goals: [GoalProgress(goal: _steps, amount: 0)],
          stepStatus: StepStatus.unavailable,
        ),
      );

      await tester.tap(find.byTooltip('Add steps'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      verify(() => cubit.addProgress('steps', 1000)).called(1);
    });
  });

  group('DailyGoalsView', () {
    late _MockDailyGoalsCubit cubit;

    Future<void> pump(WidgetTester tester, List<DailyGoal> goals) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      when(() => cubit.state).thenReturn(ViewLoaded(goals));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BlocProvider<DailyGoalsCubit>.value(
            value: cubit,
            child: const DailyGoalsView(),
          ),
        ),
      );
    }

    setUp(() => cubit = _MockDailyGoalsCubit());

    testWidgets('lists goals with their targets and reminders', (tester) async {
      await pump(tester, [_water.copyWith(reminderEnabled: true), _steps]);

      expect(find.text('3 L a day'), findsOneWidget);
      expect(find.textContaining('Every 2 h, 9:00'), findsOneWidget);
      expect(find.text('10,000 steps a day'), findsOneWidget);
      expect(find.text('Reminders off'), findsOneWidget);
    });

    testWidgets('a new custom goal is saved from the editor', (tester) async {
      when(
        () => cubit.save(any()),
      ).thenAnswer((_) async => const ActionDone<void>(null));
      await pump(tester, [_water, _steps]);

      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      // Water and steps exist already.
      expect(find.text('Already added'), findsNWidgets(2));
      await tester.tap(find.text('Your own goal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Read');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final input =
          verify(() => cubit.save(captureAny())).captured.single as GoalInput;
      expect(input.type, DailyGoalType.custom);
      expect(input.title, 'Read');
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a failed save keeps the editor open with the reason', (
      tester,
    ) async {
      when(
        () => cubit.save(any(), existing: any(named: 'existing')),
      ).thenAnswer((_) async => const ActionFailed<void>('Not allowed.'));
      await pump(tester, [_water]);

      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Not allowed.'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('removing a goal asks first', (tester) async {
      when(
        () => cubit.remove(any()),
      ).thenAnswer((_) async => const ActionDone<void>(null));
      await pump(tester, [_water]);

      await tester.tap(find.byTooltip('Remove Water'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Water?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => cubit.remove(_water)).called(1);
    });
  });
}
