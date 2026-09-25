/// Local midnight of [time]'s day.
DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

/// Whether [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The calendar day of [time] as `yyyymmdd` (20260302). Records store this
/// instead of a `DateTime` so a time-zone change never moves them to
/// another day. Keys sort in date order.
int dayKeyOf(DateTime time) => time.year * 10000 + time.month * 100 + time.day;

/// The day before [dayKey], as a key.
int previousDayKey(int dayKey) =>
    dayKeyOf(DateTime(dayKey ~/ 10000, dayKey ~/ 100 % 100, dayKey % 100 - 1));
