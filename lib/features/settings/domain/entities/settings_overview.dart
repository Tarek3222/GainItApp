import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';

class SettingsOverview extends Equatable {
  const SettingsOverview({
    required this.settings,
    this.profile,
    this.photoFile,
    this.age,
  });

  final AppSettings settings;
  final UserProfile? profile;

  /// Absolute path of the profile photo for display, or `null`.
  final String? photoFile;

  /// The user's age today, or `null` when it was never entered.
  final int? age;

  SettingsOverview withAge(int? age) => SettingsOverview(
    settings: settings,
    profile: profile,
    photoFile: photoFile,
    age: age,
  );

  @override
  List<Object?> get props => [settings, profile, photoFile, age];
}
