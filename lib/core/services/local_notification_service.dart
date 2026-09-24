import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/notification_scheduler.dart';

/// `flutter_local_notifications` implementation of [NotificationScheduler].
/// Screens never call this directly; use cases do (spec §21).
class LocalNotificationService implements NotificationScheduler {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _restCountdownId = 1000;
  static const _restOverId = 1001;
  static const _reminderBaseId = 2000;

  static const _restChannel = AndroidNotificationDetails(
    'rest_timer',
    'Rest timer',
    channelDescription: 'Alerts when your rest period is over.',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
  );

  static const _reminderChannel = AndroidNotificationDetails(
    'workout_reminders',
    'Workout reminders',
    channelDescription: 'Reminds you on scheduled training days.',
  );

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
      title: 'Resting',
      body: 'Next: $exerciseName',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_countdown',
          'Rest countdown',
          channelDescription: 'Shows the remaining rest time.',
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
      title: 'Rest over',
      body: 'Time for your next set of $exerciseName.',
      scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: _restChannel,
        iOS: DarwinNotificationDetails(presentSound: true),
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
        title: 'Workout today',
        body: '${day.workoutName} is on the plan. Let’s train.',
        scheduledDate: _nextInstance(now, day.weekday, minutesOfDay),
        notificationDetails: const NotificationDetails(
          android: _reminderChannel,
          iOS: DarwinNotificationDetails(),
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
