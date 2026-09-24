import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/app.dart';
import 'package:gainit/app/router/app_router.dart';
import 'package:gainit/core/di/injection.dart';
import 'package:gainit/core/domain/services/day_change_source.dart';
import 'package:gainit/core/domain/services/notification_scheduler.dart';
import 'package:gainit/core/storage/hive_storage.dart';
import 'package:gainit/core/storage/storage_bootstrap.dart';
import 'package:hive_ce/hive_ce.dart';

import '../helpers/fixed_clock.dart';

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
    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '178');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weight'),
      '72.4',
    );
    await tester.ensureVisible(find.text('Start training'));
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();

    // Home answers "what is next" and shows the weigh-in.
    expect(find.text('Good evening, Tarek'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('72.4 kg'), findsOneWidget);

    // Start today's workout.
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(find.text('Squat / Hack Squat'), findsWidgets);
    expect(find.text('Set 1 of 4'), findsOneWidget);
    expect(find.text('Last: no previous session'), findsOneWidget);

    // Log the first set → autosaved, next set shown, rest timer starts.
    await tester.tap(find.byTooltip('Increase kg').first);
    await tester.ensureVisible(find.text('Complete set 1'));
    await tester.tap(find.text('Complete set 1'));
    await tester.pumpAndSettle();
    expect(find.text('Set 2 of 4'), findsOneWidget);
    expect(find.text('0 of 20 sets'), findsNothing);
    expect(find.text('1 of 20 sets'), findsOneWidget);
    expect(find.text('REST'), findsOneWidget);
    expect(storage.setLogs.length, 1);

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
    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '180');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '80');
    await tester.ensureVisible(find.text('Start training'));
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('Workout history'));
    await tester.tap(find.text('Workout history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs'));
    await tester.pumpAndSettle();
    expect(find.text('Set 1'), findsOneWidget);
    await tester.tap(find.text('Squat / Hack Squat'));
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
    expect(find.text('80 kg'), findsWidgets);
  });
}
