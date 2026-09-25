import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/app.dart';
import 'package:gainit/app/router/app_router.dart';
import 'package:gainit/core/di/injection.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/services/day_change_source.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/domain/services/step_counter.dart';
import 'package:gainit/core/storage/hive_storage.dart';
import 'package:gainit/core/storage/storage_bootstrap.dart';
import 'package:hive_ce/hive_ce.dart';

import '../helpers/fake_media_store.dart';
import '../helpers/fake_step_counter.dart';
import '../helpers/fixed_clock.dart';
import '../helpers/scroll.dart';

class _NoDayChanges implements DayChangeSource {
  @override
  Stream<void> get changes => const Stream.empty();
}

class _FakeNotifications implements NotificationScheduler {
  @override
  Future<void> cancelRestOver() async {}

  @override
  Future<void> cancelWorkoutReminders() async {}

  @override
  Future<void> scheduleGoalReminders(List<GoalReminder> reminders) async {}

  @override
  Future<void> cancelGoalReminders() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleRestOver({
    required DateTime endsAt,
    required String exerciseName,
  }) async {}

  @override
  Future<void> scheduleWorkoutReminders({
    required List<({int weekday, String workoutName})> days,
    required int minutesOfDay,
  }) async {}
}

/// Boots the real app (router, DI, storage) and walks the MVP loop:
/// onboarding → home → start workout → log set → finish → summary → tabs.
void main() {
  late HiveStorage storage;

  setUp(() async {
    storage = await HiveStorage.open(inMemory: true);
    // Monday evening → "Legs" is today's workout.
    final clock = FixedClock(DateTime(2026, 3, 2, 18));
    await StorageBootstrap.run(storage, now: clock.now());
    configureDependencies(
      storage: storage,
      notifications: _FakeNotifications(),
      clock: clock,
      dayChanges: _NoDayChanges(),
      media: FakeMediaStore(),
      steps: FakeStepCounter(access: StepAccess.denied),
    );
  });

  tearDown(() async {
    await resetDependencies();
    await Hive.close();
  });

  testWidgets('complete MVP loop through the UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(GainItApp(router: createRouter()));
    await tester.pumpAndSettle();

    // Onboarding (first launch).
    expect(find.text('Welcome to GainIt'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Tarek');
    // Confirm the suggested height, weight and age (170 cm, 70 kg, 25).
    await confirmPickers(tester, ['Use 170 cm', 'Use 70 kg', 'Use 25 years']);
    await scrollPageToEnd(tester);
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();

    // Home answers "what is next" and shows the weigh-in.
    expect(find.text('Good evening, Tarek'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('70 kg'), findsOneWidget);

    // Today's progress: the default water and step goals.
    expect(find.text('0 / 3 L'), findsOneWidget);
    expect(find.text('0 / 10,000 steps'), findsOneWidget);
    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();
    expect(find.text('0.25 / 3 L'), findsOneWidget);
    expect(storage.dailyGoalLogs.values.single.amount, 250);
    // Let the "Added 250 ml · Undo" snackbar time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Start today's workout.
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(find.text('Squat / Hack Squat'), findsWidgets);
    expect(find.text('Set 1 of 4'), findsOneWidget);
    expect(find.text('Last: no previous session'), findsOneWidget);

    // Log the first set → autosaved, next set shown, rest timer starts.
    await tester.ensureVisible(find.byTooltip('Increase kg').first);
    await tester.tap(find.byTooltip('Increase kg').first);
    await tester.pump();
    await tester.ensureVisible(find.text('Complete set 1'));
    await tester.tap(find.text('Complete set 1'));
    await tester.pumpAndSettle();
    expect(find.text('Set 2 of 4'), findsOneWidget);
    expect(find.text('0 of 20 sets'), findsNothing);
    expect(find.text('1 of 20 sets'), findsOneWidget);
    expect(find.text('REST'), findsOneWidget);
    expect(storage.setLogs.length, 1);

    // While resting the next set cannot be completed; skipping unlocks it.
    final resting = find.widgetWithText(FilledButton, 'Resting…');
    await tester.ensureVisible(resting);
    expect(tester.widget<FilledButton>(resting).onPressed, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();
    final next = find.widgetWithText(FilledButton, 'Complete set 2');
    await tester.ensureVisible(next);
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);

    // Finish early from the menu.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await tester.pumpAndSettle();

    // Summary.
    expect(find.text('Workout Complete'), findsOneWidget);
    expect(find.text('Quads'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();

    // Home now counts the workout.
    expect(find.text('1/4 workouts'), findsOneWidget);

    // Every tab renders.
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Chest + Back + Traps'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Squat / Hack Squat'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Tarek'), findsOneWidget);
    expect(find.textContaining('170 cm · 25 years'), findsOneWidget);

    // Switching to imperial changes every displayed weight and height.
    await tester.tap(find.text('lb · ft'));
    await tester.pumpAndSettle();
    expect(storage.profile.values.single.unitSystem, UnitSystem.imperial);
    expect(find.textContaining('5′7″ · 25 years'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('154.3 lb'), findsOneWidget);
  });

  testWidgets('interrupted workout can be resumed; secondary screens render', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // First run: onboard, start, log one set, then "kill" the app.
    await tester.pumpWidget(GainItApp(router: createRouter()));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
    await confirmPickers(tester, ['Use 170 cm', 'Use 70 kg', 'Use 25 years']);
    await scrollPageToEnd(tester);
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Increase kg').first);
    await tester.tap(find.byTooltip('Increase kg').first);
    await tester.pump();
    await tester.ensureVisible(find.text('Complete set 1'));
    await tester.tap(find.text('Complete set 1'));
    await tester.pumpAndSettle();

    // Relaunch with a fresh widget tree (same storage).
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(GainItApp(router: createRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Resume workout?'), findsOneWidget);
    expect(find.text('1 of 20 sets completed'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('Set 2 of 4'), findsOneWidget);

    // Finish from the menu, then visit secondary screens.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();

    // Workout overview from the plan.
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shoulders + Arms'));
    await tester.pumpAndSettle();
    expect(find.textContaining('22 working sets'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // History → session detail → exercise progress.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Workout history'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Workout history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs'));
    await tester.pumpAndSettle();
    expect(find.text('Set 1'), findsOneWidget);
    await tester.tap(find.text('Squat / Hack Squat'));
    await tester.pumpAndSettle();
    // Guide tab: target muscles and the bundled research guide.
    expect(find.text('TARGET MUSCLES'), findsOneWidget);
    expect(find.text('Quads'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('WHAT RESEARCH SAYS'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Kubo K'), findsOneWidget);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Est. 1RM'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Body weight log.
    await tester.tap(find.text('BODY WEIGHT'));
    await tester.pumpAndSettle();
    expect(find.text('Log weight'), findsOneWidget);
    expect(find.text('70 kg'), findsWidgets);
  });

  testWidgets('a workout day and the exercise library can be customised', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(GainItApp(router: createRouter()));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
    await confirmPickers(tester, ['Use 170 cm', 'Use 70 kg', 'Use 25 years']);
    await scrollPageToEnd(tester);
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();

    // Plan → edit Monday.
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Edit Legs'));
    await tester.tap(find.byTooltip('Edit Legs'));
    await tester.pumpAndSettle();
    expect(find.text('Edit day'), findsOneWidget);

    // Rename the day.
    await tester.tap(find.text('Legs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lower body');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Lower body'), findsOneWidget);

    // Add an exercise from the library.
    await tester.scrollUntilVisible(
      find.text('Add exercise'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hammer');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hammer Curl'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hammer Curl'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hammer Curl'), findsOneWidget);
    expect(
      storage.programExercises.values.where(
        (p) => p.workoutDayId == 'day_mon_legs',
      ),
      hasLength(7),
    );

    // Create a custom exercise from the library.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Exercise library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Nordic Curl',
    );
    await scrollPageToEnd(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nordic');
    await tester.pumpAndSettle();
    expect(find.text('Nordic Curl'), findsOneWidget);
    expect(
      storage.exercises.values.where((e) => e.isCustom).single.name,
      'Nordic Curl',
    );
  });
}
