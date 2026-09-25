import 'package:equatable/equatable.dart';

/// Small user preferences (never workout history).
class AppSettings extends Equatable {
  const AppSettings({
    this.autoStartRestTimer = true,
    this.restAlertsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.remindersEnabled = false,
    this.reminderMinutesOfDay = 18 * 60,
    this.languageCode,
  });

  /// Languages the app is translated into.
  static const supportedLanguageCodes = ['en', 'ar'];

  final bool autoStartRestTimer;

  /// Notify when rest is over while the app is in the background.
  final bool restAlertsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool remindersEnabled;

  /// Local time of the workout reminder, as minutes after midnight.
  final int reminderMinutesOfDay;

  /// App language (see [supportedLanguageCodes]); `null` follows the
  /// phone's language.
  final String? languageCode;

  AppSettings copyWith({
    bool? autoStartRestTimer,
    bool? restAlertsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? remindersEnabled,
    int? reminderMinutesOfDay,
    String? languageCode,
    bool useSystemLanguage = false,
  }) {
    return AppSettings(
      autoStartRestTimer: autoStartRestTimer ?? this.autoStartRestTimer,
      restAlertsEnabled: restAlertsEnabled ?? this.restAlertsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderMinutesOfDay: reminderMinutesOfDay ?? this.reminderMinutesOfDay,
      languageCode: useSystemLanguage
          ? null
          : languageCode ?? this.languageCode,
    );
  }

  @override
  List<Object?> get props => [
    autoStartRestTimer,
    restAlertsEnabled,
    soundEnabled,
    vibrationEnabled,
    remindersEnabled,
    reminderMinutesOfDay,
    languageCode,
  ];
}
