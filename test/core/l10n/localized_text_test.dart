import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/l10n/enum_labels.dart';
import 'package:gainit/core/l10n/seed_names.dart';
import 'package:gainit/core/presentation/failure_message.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:gainit/core/utils/formatters.dart';

import '../../helpers/localization.dart';

void main() {
  tearDown(loadTestTranslations);

  group('English', () {
    test('built-in names are shown as stored', () {
      expect(seedName('Hammer Curl'), 'Hammer Curl');
    });

    test('validation messages fill in their limits', () {
      expect(
        const ValidationFailure(['validation.repsMax']).userMessage,
        'Reps must be 200 or fewer.',
      );
    });

    test('an unknown message is shown as it is', () {
      expect(
        const InvalidStateFailure('Something custom').userMessage,
        'Something custom',
      );
    });
  });

  group('Arabic', () {
    setUp(() => loadTestTranslations('ar'));

    test('built-in names are translated', () {
      expect(seedName('Hammer Curl'), 'باي هامر');
      expect(seedName('Legs'), 'أرجل');
    });

    test('names the user typed stay as typed', () {
      expect(seedName('My Curl'), 'My Curl');
      expect(seedName('v1.2 press'), 'v1.2 press');
    });

    test('names inside messages are translated too', () {
      expect(
        const InvalidStateFailure(
          'errors.finishOtherWorkout',
          args: {'name': 'Legs'},
        ).userMessage,
        'أنهِ جلسة «أرجل» أو احذفها قبل بدء جلسة أخرى.',
      );
    });

    test('enum labels follow the language', () {
      expect(MuscleGroup.chest.label, 'صدر');
      expect(TrainingGoal.cut.label, 'تنشيف');
    });

    test('dates are in Arabic with Western digits', () {
      final text = Formatters.shortDate(DateTime(2026, 3, 2));

      expect(text, contains('2'));
      expect(text, contains('مارس'));
      expect(text, isNot(contains('٢')));
    });

    test('units are in Arabic', () {
      expect(Formatters.kg(72.5), '72.5 كجم');
    });
  });
}
