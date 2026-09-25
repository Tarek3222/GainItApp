import 'package:easy_localization/easy_localization.dart';

import '../domain/entities/enums.dart';

/// Display names of domain enums in the current language.

extension MuscleGroupLabel on MuscleGroup {
  String get label => 'muscles.$name'.tr();
}

extension TrainingGoalLabel on TrainingGoal {
  String get label => 'trainingGoals.$name'.tr();
}
