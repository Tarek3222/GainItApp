import 'package:easy_localization/easy_localization.dart';

/// Display formatting shared by every feature.
abstract final class Formatters {
  /// `30` → "30", `32.5` → "32.5", `32.25` → "32.25".
  static String weight(num value) {
    final v = value.toDouble();
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final text = v.toStringAsFixed(2);
    return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
  }

  static String kg(num value) => '${weight(value)} ${'units.kg'.tr()}';

  static String signedKg(num value) {
    final sign = value > 0 ? '+' : (value < 0 ? '−' : '±');
    return '$sign${weight(value.abs())} ${'units.kg'.tr()}';
  }

  /// Rest in seconds → "2 min", "1–1.5 min", "90 s", "—".
  static String rest(int minSeconds, int maxSeconds) {
    if (minSeconds <= 0 && maxSeconds <= 0) return '—';
    String part(int s) {
      if (s < 60) return '$s';
      final minutes = s / 60;
      return minutes == minutes.roundToDouble()
          ? minutes.toStringAsFixed(0)
          : minutes.toStringAsFixed(1);
    }

    final unit = (maxSeconds < 60 ? 'units.sec' : 'units.min').tr();
    if (minSeconds == maxSeconds || maxSeconds <= 0) {
      return '${part(minSeconds)} $unit';
    }
    return '${part(minSeconds)}–${part(maxSeconds)} $unit';
  }

  static String repRange(int min, int max) => 'formats.reps'.tr(
    namedArgs: {'range': min == max ? '$min' : '$min–$max'},
  );

  /// "10/9/8"
  static String repsList(Iterable<int> reps) => reps.join('/');

  static String timer(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// "52 min", "1 h 05 min"
  static String duration(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 60) return '$minutes ${'units.min'.tr()}';
    return '${minutes ~/ 60} ${'units.hourShort'.tr()} '
        '${(minutes % 60).toString().padLeft(2, '0')} ${'units.minShort'.tr()}';
  }

  // Dates use the app language (`Intl.defaultLocale`) with Western digits,
  // like every other number in the app.
  static DateFormat _latin(DateFormat format) =>
      format..useNativeDigits = false;

  static String shortDate(DateTime d) => _latin(DateFormat.MMMd()).format(d);

  static String fullDate(DateTime d) => _latin(DateFormat.yMMMEd()).format(d);

  static String weekday(int weekday) => _latin(
    DateFormat.EEEE(),
  ).format(DateTime(2024, 1, weekday)); // 2024-01-01 = Mon

  static String weekdayShort(int weekday) =>
      _latin(DateFormat.E()).format(DateTime(2024, 1, weekday));

  static String timeOfDay(int minutesOfDay) => _latin(
    DateFormat.jm(),
  ).format(DateTime(2024, 1, 1, minutesOfDay ~/ 60, minutesOfDay % 60));
}
