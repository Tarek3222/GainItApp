import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/user_profile.dart';

void main() {
  UserProfile bornOn(DateTime? date) => UserProfile(
    id: 'me',
    name: 'Sam',
    heightCm: 180,
    goal: TrainingGoal.maintain,
    trainingStartDate: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    birthDate: date,
  );

  test('age is anchored on the day it was entered', () {
    // Entered "25" on 31 Dec 2026.
    final born = UserProfile.birthDateFor(25, DateTime(2026, 12, 31));
    final profile = bornOn(born);

    expect(profile.ageOn(DateTime(2026, 12, 31)), 25);
    // The next day is a new year but not a new age.
    expect(profile.ageOn(DateTime(2027)), 25);
    expect(profile.ageOn(DateTime(2027, 12, 30)), 25);
    expect(profile.ageOn(DateTime(2027, 12, 31)), 26);
  });

  test('no birth date means no age', () {
    expect(bornOn(null).ageOn(DateTime(2026)), isNull);
  });
}
