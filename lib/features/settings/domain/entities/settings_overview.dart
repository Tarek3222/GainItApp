import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/user_profile.dart';

class SettingsOverview extends Equatable {
  const SettingsOverview({required this.settings, this.profile});

  final AppSettings settings;
  final UserProfile? profile;

  @override
  List<Object?> get props => [settings, profile];
}
