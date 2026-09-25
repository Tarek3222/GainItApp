import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/domain/entities/body_weight_entry.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/training/body_weight_trend.dart';
import 'package:gainit/core/domain/training/performance_comparator.dart';
import 'package:gainit/core/domain/training/progression_engine.dart';
import 'package:gainit/core/presentation/units/unit_format.dart';
import 'package:gainit/core/presentation/view_state.dart';
import 'package:gainit/core/widgets/measure_wheel_picker.dart';
import 'package:gainit/features/daily_goals/domain/entities/daily_goal_entities.dart';
import 'package:gainit/features/daily_goals/presentation/cubits/daily_goal_cubits.dart';
import 'package:gainit/features/home/domain/entities/home_dashboard.dart';
import 'package:gainit/features/home/presentation/cubits/home_cubit.dart';
import 'package:gainit/features/home/presentation/views/home_view.dart';
import 'package:gainit/features/onboarding/domain/entities/onboarding_input.dart';
import 'package:gainit/features/onboarding/presentation/cubits/onboarding_cubit.dart';
import 'package:gainit/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:gainit/features/workout/domain/entities/active_workout.dart';
import 'package:gainit/features/workout/domain/entities/workout_summary.dart';
import 'package:gainit/features/workout/presentation/cubits/workout_summary_cubit.dart';
import 'package:gainit/features/workout/presentation/views/workout_summary_view.dart';
import 'package:gainit/features/workout/presentation/widgets/exercise_panel.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';
import '../helpers/scroll.dart';

class _MockHomeCubit extends MockCubit<ViewState<HomeDashboard>>
    implements HomeCubit {}

class _MockTodayGoalsCubit extends MockCubit<ViewState<TodayGoals>>
    implements TodayGoalsCubit {}

class _MockSummaryCubit extends MockCubit<WorkoutSummaryState>
    implements WorkoutSummaryCubit {}

class _MockOnboardingCubit extends MockCubit<OnboardingState>
    implements OnboardingCubit {}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(
    () => registerFallbackValue(
      OnboardingInput(
        name: '',
        heightCm: 0,
        weightKg: 0,
        age: 30,
        goal: TrainingGoal.maintain,
        trainingStartDate: DateTime(2026),
      ),
    ),
  );

  testWidgets('Home renders the next workout, body weight and this week', (
    tester,
  ) async {
    final cubit = _MockHomeCubit();
    when(() => cubit.state).thenReturn(
      ViewLoaded(
        HomeDashboard(
          greeting: GreetingTime.evening,
          name: 'Tarek',
          weekNumber: 4,
          programName: 'Hypertrophy',
          nextWorkout: NextWorkoutInfo(
            dayId: 'day_sun',
            name: 'Chest + Back + Traps',
            date: DateTime(2026, 3, 1),
            isToday: true,
            exerciseCount: 7,
            totalSets: 19,
          ),
          bodyWeight: BodyWeightSummary(
            latest: BodyWeightEntry(
              id: 'w',
              weightKg: 72.4,
              measuredAt: DateTime(2026, 3, 1),
            ),
            changeOverPeriod: 0.4,
            periodDays: 14,
          ),
          weekCompletedWorkouts: 3,
          weekPlannedWorkouts: 4,
          weekWorkingSets: 46,
        ),
      ),
    );

    final goals = _MockTodayGoalsCubit();
    when(() => goals.state).thenReturn(
      const ViewLoaded(TodayGoals(goals: [], stepStatus: StepStatus.active)),
    );

    await tester.pumpWidget(
      _app(
        MultiBlocProvider(
          providers: [
            BlocProvider<HomeCubit>.value(value: cubit),
            BlocProvider<TodayGoalsCubit>.value(value: goals),
          ],
          child: const HomeView(),
        ),
      ),
    );

    expect(find.text('Good evening, Tarek'), findsOneWidget);
    expect(find.text('Chest + Back + Traps'), findsOneWidget);
    expect(find.textContaining('19 sets'), findsOneWidget);
    expect(find.text('72.4 kg'), findsOneWidget);
    expect(find.text('3/4 workouts'), findsOneWidget);
    expect(find.text('46 working sets'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
  });

  testWidgets('Home keeps daily goals usable when its own data fails', (
    tester,
  ) async {
    final cubit = _MockHomeCubit();
    when(() => cubit.state).thenReturn(const ViewError('Could not load.'));
    final goals = _MockTodayGoalsCubit();
    when(() => goals.state).thenReturn(
      const ViewLoaded(TodayGoals(goals: [], stepStatus: StepStatus.active)),
    );

    await tester.pumpWidget(
      _app(
        MultiBlocProvider(
          providers: [
            BlocProvider<HomeCubit>.value(value: cubit),
            BlocProvider<TodayGoalsCubit>.value(value: goals),
          ],
          child: const HomeView(),
        ),
      ),
    );

    expect(find.text('Could not load.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('TODAY’S PROGRESS'), findsOneWidget);
  });

  group('ExercisePanel', () {
    ActiveExercise exercise({int loggedSets = 0}) => ActiveExercise(
      snapshot: Fixtures.sessionExercise(),
      sets: [
        for (var i = 1; i <= loggedSets; i++)
          Fixtures.set(number: i, weight: 32.5, reps: 8),
      ],
      lastPerformance: Fixtures.performance([(30, 12), (30, 12), (30, 12)]),
      recommendation: const Recommendation(
        type: RecommendationType.increaseWeight,
        suggestedWeight: 32.5,
        previousWeight: 30,
        repMin: 6,
        repMax: 10,
        targetReps: 6,
      ),
    );

    testWidgets('shows target and previous performance', (tester) async {
      await tester.pumpWidget(
        _app(
          ExercisePanel(
            exercise: exercise(),
            onLogSet: (_, _, _) async {},
            onUndoSet: (_) {},
            onToggleSkip: () {},
          ),
        ),
      );

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('32.5 kg · 6–10 reps'), findsOneWidget);
      expect(find.text('Last: 30 kg · 12/12/12'), findsOneWidget);
      expect(find.text('Set 1 of 3'), findsOneWidget);
    });

    testWidgets('completing a set sends the edited values', (tester) async {
      (double, int, int?)? logged;
      await tester.pumpWidget(
        _app(
          ExercisePanel(
            exercise: exercise(),
            onLogSet: (w, r, rir) async => logged = (w, r, rir),
            onUndoSet: (_) {},
            onToggleSkip: () {},
          ),
        ),
      );

      await tester.tap(find.byTooltip('Increase reps'));
      await tester.tap(find.widgetWithText(ChoiceChip, '2'));
      await tester.pump();
      await tester.ensureVisible(find.text('Complete set 1'));
      await tester.tap(find.text('Complete set 1'));
      await tester.pump();

      expect(logged, (32.5, 7, 2));
    });

    testWidgets('cannot complete a set while the rest timer runs', (
      tester,
    ) async {
      var logged = false;
      await tester.pumpWidget(
        _app(
          ExercisePanel(
            exercise: exercise(),
            isResting: true,
            onLogSet: (_, _, _) async => logged = true,
            onUndoSet: (_) {},
            onToggleSkip: () {},
          ),
        ),
      );

      final button = find.widgetWithText(FilledButton, 'Resting…');
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.pump();

      expect(logged, isFalse);
    });

    testWidgets('cannot complete a set without a weight above 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ExercisePanel(
            exercise: ActiveExercise(
              snapshot: Fixtures.sessionExercise(),
              sets: const [],
              lastPerformance: null,
              recommendation: const Recommendation(
                type: RecommendationType.firstSession,
                repMin: 6,
                repMax: 10,
                targetReps: 6,
              ),
            ),
            onLogSet: (_, _, _) async {},
            onUndoSet: (_) {},
            onToggleSkip: () {},
          ),
        ),
      );

      final button = find.widgetWithText(FilledButton, 'Complete set 1');
      await tester.ensureVisible(button);
      expect(find.text('Enter a weight above 0'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.byTooltip('Increase kg'));
      await tester.pump();

      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('imperial users see and edit weights in lb', (tester) async {
      (double, int, int?)? logged;
      await tester.pumpWidget(
        _app(
          UnitScope(
            system: UnitSystem.imperial,
            child: ExercisePanel(
              exercise: ActiveExercise(
                snapshot: Fixtures.sessionExercise(),
                sets: const [],
                lastPerformance: Fixtures.performance([(30, 8)]),
                recommendation: const Recommendation(
                  type: RecommendationType.addReps,
                  suggestedWeight: 30,
                  previousWeight: 30,
                  repMin: 6,
                  repMax: 10,
                  targetReps: 9,
                ),
              ),
              onLogSet: (w, r, rir) async => logged = (w, r, rir),
              onUndoSet: (_) {},
              onToggleSkip: () {},
            ),
          ),
        ),
      );

      expect(find.text('66.1 lb · 6–10 reps'), findsOneWidget);
      // The stepper uses the same 1-decimal lb formatting as the card.
      expect(find.text('66.1'), findsOneWidget);

      // +1 lb from 66.14 lb lands on 67 lb, saved in kg.
      await tester.tap(find.byTooltip('Increase lb'));
      await tester.pump();
      await tester.ensureVisible(find.text('Complete set 1'));
      await tester.tap(find.text('Complete set 1'));
      await tester.pump();

      expect(logged!.$1, closeTo(67 * 0.45359237, 0.001));
    });

    testWidgets('shows logged sets and the next set number', (tester) async {
      await tester.pumpWidget(
        _app(
          ExercisePanel(
            exercise: exercise(loggedSets: 2),
            onLogSet: (_, _, _) async {},
            onUndoSet: (_) {},
            onToggleSkip: () {},
          ),
        ),
      );

      expect(find.text('32.5 kg × 8'), findsNWidgets(2));
      expect(find.text('Set 3 of 3'), findsOneWidget);
      // Only the latest set can be undone.
      expect(find.byTooltip('Undo set 2'), findsOneWidget);
      expect(find.byTooltip('Undo set 1'), findsNothing);
    });
  });

  testWidgets('Workout summary lists volume and progress', (tester) async {
    final cubit = _MockSummaryCubit();
    when(() => cubit.state).thenReturn(
      WorkoutSummaryLoaded(
        WorkoutSummary(
          sessionId: 's1',
          workoutName: 'Chest + Back + Traps',
          duration: const Duration(minutes: 52),
          workingSets: 19,
          volume: const {MuscleGroup.chest: 8, MuscleGroup.back: 8},
          lines: [
            ExerciseProgressLine(
              exerciseId: 'ex_bench',
              exerciseName: 'Bench Press',
              current: Fixtures.performance([(30, 11), (30, 10), (30, 9)]),
              previous: Fixtures.performance([(30, 10), (30, 9), (30, 8)]),
              comparison: const PerformanceComparison(
                outcome: ProgressOutcome.repsIncreased,
                repsDelta: 3,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<WorkoutSummaryCubit>.value(
          value: cubit,
          child: const WorkoutSummaryView(),
        ),
      ),
    );

    expect(find.text('Workout Complete'), findsOneWidget);
    expect(find.text('19 working sets · 52 min'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('+3 reps'), findsOneWidget);
  });

  testWidgets('Onboarding submits picker values in metric storage units', (
    tester,
  ) async {
    final cubit = _MockOnboardingCubit();
    when(() => cubit.state).thenReturn(const OnboardingIdle());
    when(() => cubit.today).thenReturn(DateTime(2026, 3, 1));
    when(() => cubit.submit(any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<OnboardingCubit>.value(
          value: cubit,
          child: const OnboardingView(),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
    await tester.tap(find.text('lb · ft'));
    await tester.pumpAndSettle();
    // Imperial pickers show the same defaults in feet and pounds.
    await confirmPickers(tester, ['Use 5′7″', 'Use 154.3 lb', 'Use 25 years']);
    expect(find.text('5′7″'), findsOneWidget);
    expect(find.text('154.3 lb'), findsOneWidget);
    await scrollPageToEnd(tester);
    await tester.tap(find.text('Start training'));
    await tester.pump();

    final input =
        verify(() => cubit.submit(captureAny())).captured.single
            as OnboardingInput;
    expect(input.unitSystem, UnitSystem.imperial);
    expect(input.heightCm, 170);
    expect(input.weightKg, 70);
    expect(input.age, 25);
  });

  testWidgets('scrolling the age wheel changes the value', (tester) async {
    var age = 25;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) =>
                AgePicker(age: age, onChanged: (a) => setState(() => age = a)),
          ),
        ),
      ),
    );

    // One item is 40 px: drag up by two items.
    await tester.drag(find.text('25'), const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(age, 27);
    expect(find.text('27 years'), findsOneWidget);
  });

  testWidgets('weight wheel never goes above the 400 kg limit', (tester) async {
    final reported = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BodyWeightPicker(
            weightKg: 400,
            system: UnitSystem.metric,
            onChanged: reported.add,
          ),
        ),
      ),
    );

    final tenths = find.byWidgetPredicate(
      (w) => w is WheelNumberPicker && w.semanticLabel == 'Weight, tenths',
    );
    await tester.drag(tenths, const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(reported, isNotEmpty);
    expect(reported, everyElement(400));
  });

  group('wheel limits', () {
    Finder wheel(String label) => find.byWidgetPredicate(
      (w) => w is WheelNumberPicker && w.semanticLabel == label,
    );

    Future<List<double>> pump(WidgetTester tester, Widget picker) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: picker)),
        ),
      );
      return [];
    }

    testWidgets('3 ft 0 in is raised to the 100 cm minimum', (tester) async {
      final reported = <double>[];
      await pump(
        tester,
        HeightPicker(
          heightCm: 101.6, // 3′4″
          system: UnitSystem.imperial,
          onChanged: reported.add,
        ),
      );

      await tester.drag(wheel('Height, inches'), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      expect(reported, everyElement(greaterThanOrEqualTo(100)));
    });

    testWidgets('8 ft 11 in is capped at the 250 cm maximum', (tester) async {
      final reported = <double>[];
      await pump(
        tester,
        HeightPicker(
          heightCm: 248.9, // 8′2″
          system: UnitSystem.imperial,
          onChanged: reported.add,
        ),
      );

      await tester.drag(wheel('Height, inches'), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      expect(reported, everyElement(lessThanOrEqualTo(250)));
    });

    testWidgets('lb weights never go below 20 kg', (tester) async {
      final reported = <double>[];
      await pump(
        tester,
        BodyWeightPicker(
          weightKg: 21, // 46.3 lb
          system: UnitSystem.imperial,
          onChanged: reported.add,
        ),
      );
      await tester.drag(wheel('Weight, whole lb'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      expect(reported, everyElement(greaterThanOrEqualTo(20)));
    });

    testWidgets('lb weights never go above 400 kg', (tester) async {
      final reported = <double>[];
      await pump(
        tester,
        BodyWeightPicker(
          weightKg: 399.95, // 881.7 lb
          system: UnitSystem.imperial,
          onChanged: reported.add,
        ),
      );
      // 881.7 → 881.9 lb, which is 400.03 kg.
      await tester.drag(wheel('Weight, tenths'), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      expect(reported.last, 400);
      expect(reported, everyElement(lessThanOrEqualTo(400)));
    });
  });

  testWidgets('Onboarding asks for every measurement before submitting', (
    tester,
  ) async {
    final cubit = _MockOnboardingCubit();
    when(() => cubit.state).thenReturn(const OnboardingIdle());
    when(() => cubit.today).thenReturn(DateTime(2026, 3, 1));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<OnboardingCubit>.value(
          value: cubit,
          child: const OnboardingView(),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
    // Only the height is confirmed.
    await confirmPickers(tester, ['Use 170 cm']);
    await scrollPageToEnd(tester);
    await tester.tap(find.text('Start training'));
    await tester.pump();

    expect(find.text('Choose your height'), findsNothing);
    expect(find.text('Choose your weight'), findsOneWidget);
    expect(find.text('Choose your age'), findsOneWidget);
    verifyNever(() => cubit.submit(any()));
  });

  testWidgets('Onboarding validates required fields before submitting', (
    tester,
  ) async {
    final cubit = _MockOnboardingCubit();
    when(() => cubit.state).thenReturn(const OnboardingIdle());
    when(() => cubit.today).thenReturn(DateTime(2026, 3, 1));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<OnboardingCubit>.value(
          value: cubit,
          child: const OnboardingView(),
        ),
      ),
    );
    await scrollPageToEnd(tester);
    await tester.tap(find.text('Start training'));
    await tester.pump();
    await scrollPageToTop(tester);

    expect(find.text('Enter your name'), findsOneWidget);
    verifyNever(() => cubit.submit(any()));
  });
}
