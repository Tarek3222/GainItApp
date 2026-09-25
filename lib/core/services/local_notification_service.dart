import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/enums.dart';
import '../domain/services/notification_scheduler.dart';
import '../l10n/seed_names.dart';

/// `flutter_local_notifications` implementation of [NotificationScheduler].
/// Screens never call this directly; use cases do (spec §21).
class LocalNotificationService implements NotificationScheduler {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _restCountdownId = 1000;
  static const _restOverId = 1001;
  static const _reminderBaseId = 2000;
  static const _goalReminderBaseId = 3000;

  // Texts are looked up when a notification is scheduled, so they follow
  // the app language (channel names update the next time one is posted).
  static AndroidNotificationDetails get _restChannel =>
      AndroidNotificationDetails(
        'rest_timer',
        'notifications.restChannel'.tr(),
        channelDescription: 'notifications.restChannelInfo'.tr(),
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      );

  static AndroidNotificationDetails get _reminderChannel =>
      AndroidNotificationDetails(
        'workout_reminders',
        'notifications.reminderChannel'.tr(),
        channelDescription: 'notifications.reminderChannelInfo'.tr(),
      );

  static AndroidNotificationDetails get _goalChannel =>
      AndroidNotificationDetails(
        'daily_goals',
        'notifications.goalChannel'.tr(),
        channelDescription: 'notifications.goalChannelInfo'.tr(),
      );

  /// Texts come from the app's translations, which follow the app language
  /// (`Intl.defaultLocale` is set from it).
  @override
  String get textLanguage => Intl.defaultLocale ?? 'en';

  Future<void>? _init;

  /// Idempotent. Concurrent callers share one initialisation. After a
  /// failure the next call tries again.
  Future<void> init() {
    return _init ??= _initialize().catchError((Object error) {
      _init = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: true) ??
          false;
    }
    return false;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> scheduleRestOver({
    required DateTime endsAt,
    required String exerciseName,
  }) async {
    await init();
    await cancelRestOver();
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return;

    // Live countdown in the shade while the app is in the background.
    await _plugin.show(
      id: _restCountdownId,
      title: 'notifications.resting'.tr(),
      body: 'notifications.next'.tr(namedArgs: {'exercise': exerciseName}),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_countdown',
          'notifications.countdownChannel'.tr(),
          channelDescription: 'notifications.countdownChannelInfo'.tr(),
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          when: endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          timeoutAfter: remaining.inMilliseconds,
        ),
      ),
    );

    await _plugin.zonedSchedule(
      id: _restOverId,
      title: 'notifications.restOver'.tr(),
      body: 'notifications.nextSet'.tr(namedArgs: {'exercise': exerciseName}),
      scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
      notificationDetails: NotificationDetails(
        android: _restChannel,
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: await _scheduleMode(),
    );
  }

  @override
  Future<void> cancelRestOver() async {
    await init();
    await _plugin.cancel(id: _restCountdownId);
    await _plugin.cancel(id: _restOverId);
  }

  @override
  Future<void> scheduleWorkoutReminders({
    required List<({int weekday, String workoutName})> days,
    required int minutesOfDay,
  }) async {
    await init();
    await cancelWorkoutReminders();
    final now = tz.TZDateTime.now(tz.local);
    for (final day in days) {
      await _plugin.zonedSchedule(
        id: _reminderBaseId + day.weekday,
        title: 'notifications.workoutToday'.tr(),
        body: 'notifications.workoutTodayBody'.tr(
          namedArgs: {'workout': seedName(day.workoutName)},
        ),
        scheduledDate: _nextInstance(now, day.weekday, minutesOfDay),
        notificationDetails: NotificationDetails(
          android: _reminderChannel,
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  @override
  Future<void> cancelWorkoutReminders() async {
    await init();
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _reminderBaseId + weekday);
    }
  }

  @override
  Future<void> scheduleGoalReminders(List<GoalReminder> reminders) async {
    await init();
    await cancelGoalReminders();
    final now = tz.TZDateTime.now(tz.local);
    final count = reminders.length < NotificationScheduler.maxGoalReminders
        ? reminders.length
        : NotificationScheduler.maxGoalReminders;
    for (var i = 0; i < count; i++) {
      final reminder = reminders[i];
      final (title, body) = _goalText(reminder);
      await _plugin.zonedSchedule(
        id: _goalReminderBaseId + i,
        title: title,
        body: body,
        scheduledDate: nextDaily(
          now,
          reminder.minutesOfDay,
          skipToday: reminder.skipToday,
        ),
        notificationDetails: NotificationDetails(
          android: _goalChannel,
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeatsDaily(reminder, defaultTargetPlatform)
            ? DateTimeComponents.time
            : null,
      );
    }
  }

  @override
  Future<void> cancelGoalReminders() async {
    await init();
    for (var i = 0; i < NotificationScheduler.maxGoalReminders; i++) {
      await _plugin.cancel(id: _goalReminderBaseId + i);
    }
  }

  static (String, String) _goalText(GoalReminder reminder) =>
      switch (reminder.type) {
        DailyGoalType.water => (
          'notifications.waterTitle'.tr(),
          'notifications.waterBody'.tr(),
        ),
        DailyGoalType.steps => (
          'notifications.stepsTitle'.tr(),
          'notifications.stepsBody'.tr(),
        ),
        DailyGoalType.custom => (
          reminder.title,
          'notifications.customBody'.tr(),
        ),
      };

  /// Whether [reminder] is scheduled as a daily repeat.
  ///
  /// A daily repeat on iOS keeps only the time of day and drops the date,
  /// so it would still fire today. A goal reached today therefore gets a
  /// one-off reminder for tomorrow there instead; the next sync (on
  /// launch, resume or at midnight) turns it back into a daily repeat.
  @visibleForTesting
  static bool repeatsDaily(GoalReminder reminder, TargetPlatform platform) =>
      !(reminder.skipToday && platform == TargetPlatform.iOS);

  /// First time a daily reminder at [minutesOfDay] fires: later today, or
  /// tomorrow when that time has passed or the goal is reached today.
  @visibleForTesting
  static tz.TZDateTime nextDaily(
    tz.TZDateTime now,
    int minutesOfDay, {
    required bool skipToday,
  }) {
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    if (!skipToday && today.isAfter(now)) return today;
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
  }

  static tz.TZDateTime _nextInstance(
    tz.TZDateTime now,
    int weekday,
    int minutesOfDay,
  ) {
    var date = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    while (date.weekday != weekday || !date.isAfter(now)) {
      date = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day + 1,
        date.hour,
        date.minute,
      );
    }
    return date;
  }
}
