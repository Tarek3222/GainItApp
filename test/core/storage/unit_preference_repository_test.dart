import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/user_profile.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/storage/local_data_sources/profile_local_data_source.dart';
import 'package:gainit/core/storage/repositories/unit_preference_repository_impl.dart';

import '../../helpers/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('emits metric before onboarding, then the saved choice', () async {
    final profiles = ProfileLocalDataSource(harness.storage);
    final repository = UnitPreferenceRepositoryImpl(profiles);
    final seen = <UnitSystem>[];
    final subscription = repository.watch().listen((result) {
      if (result case ApiSuccess(:final data)) seen.add(data);
    });
    await pumpEventQueue();

    await profiles.save(
      UserProfile(
        id: 'me',
        name: 'Sam',
        heightCm: 180,
        goal: TrainingGoal.cut,
        trainingStartDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        unitSystem: UnitSystem.imperial,
      ),
    );
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [UnitSystem.metric, UnitSystem.imperial]);
  });
}
