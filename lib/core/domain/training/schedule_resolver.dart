import 'package:equatable/equatable.dart';

import '../entities/program.dart';
import '../utils/dates.dart' as dates;

enum DayStatus {
  completed,
  today,
  upcoming,
  missed,
  rest,

  /// Scheduled before the program started — never counted as missed.
  beforeStart,
}

class ScheduledWorkout extends Equatable {
  const ScheduledWorkout({
    required this.day,
    required this.date,
    required this.isToday,
  });

  final WorkoutDay day;
  final DateTime date;
  final bool isToday;

  @override
  List<Object?> get props => [day, date, isToday];
}

/// Calendar logic for the weekly program. The GainIt week starts on Saturday.
abstract final class ScheduleResolver {
  static const weekStartsOn = DateTime.saturday;

  static DateTime dateOnly(DateTime d) => dates.dateOnly(d);

  /// Position of a weekday in the GainIt week (Saturday = 0 … Friday = 6).
  static int offsetInWeek(int weekday) => (weekday - weekStartsOn) % 7;

  static DateTime weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day - offsetInWeek(date.weekday));

  static DateTime weekEnd(DateTime date) {
    final start = weekStart(date);
    return DateTime(start.year, start.month, start.day + 7);
  }

  /// Whole calendar days between two dates, immune to DST shifts.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// 1-based training week since [programStart].
  static int weekNumber(DateTime programStart, DateTime today) {
    final days = daysBetween(weekStart(programStart), weekStart(today));
    if (days < 0) return 1;
    return days ~/ 7 + 1;
  }

  static DateTime dateInWeekOf(WorkoutDay day, DateTime reference) {
    final start = weekStart(reference);
    return DateTime(
      start.year,
      start.month,
      start.day + offsetInWeek(day.weekday),
    );
  }

  static List<WorkoutDay> ordered(Iterable<WorkoutDay> days) => days.toList()
    ..sort(
      (a, b) => offsetInWeek(a.weekday).compareTo(offsetInWeek(b.weekday)),
    );

  /// Today's workout if it isn't done yet, otherwise the next scheduled one.
  static ScheduledWorkout? nextWorkout({
    required List<WorkoutDay> days,
    required DateTime today,
    required Set<String> completedDayIdsThisWeek,
  }) {
    final workouts = ordered(days.where((d) => d.isWorkout));
    if (workouts.isEmpty) return null;
    final todayOffset = offsetInWeek(today.weekday);

    for (final day in workouts) {
      final offset = offsetInWeek(day.weekday);
      if (offset < todayOffset) continue;
      if (completedDayIdsThisWeek.contains(day.id)) continue;
      return ScheduledWorkout(
        day: day,
        date: dateInWeekOf(day, today),
        isToday: offset == todayOffset,
      );
    }

    final first = workouts.first;
    final nextWeek = DateTime(today.year, today.month, today.day + 7);
    return ScheduledWorkout(
      day: first,
      date: dateInWeekOf(first, nextWeek),
      isToday: false,
    );
  }

  static DayStatus statusOf({
    required WorkoutDay day,
    required DateTime today,
    required Set<String> completedDayIdsThisWeek,
    DateTime? programStart,
  }) {
    if (!day.isWorkout) return DayStatus.rest;
    if (completedDayIdsThisWeek.contains(day.id)) return DayStatus.completed;
    if (programStart != null &&
        dateInWeekOf(day, today).isBefore(dateOnly(programStart))) {
      return DayStatus.beforeStart;
    }
    final offset = offsetInWeek(day.weekday);
    final todayOffset = offsetInWeek(today.weekday);
    if (offset == todayOffset) return DayStatus.today;
    return offset < todayOffset ? DayStatus.missed : DayStatus.upcoming;
  }
}
