import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/validation/validators.dart';
import 'package:gainit/features/home/domain/entities/home_dashboard.dart';

import '../../helpers/localization.dart';

/// Flattens nested translations to dotted keys. Plural groups stay whole.
Map<String, Object> _flatten(Map<String, dynamic> tree, [String prefix = '']) {
  const pluralForms = {'zero', 'one', 'two', 'few', 'many', 'other'};
  final flat = <String, Object>{};
  for (final MapEntry(:key, :value) in tree.entries) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic> &&
        !(value.keys.every(pluralForms.contains) &&
            value.containsKey('other'))) {
      flat.addAll(_flatten(value, path));
    } else {
      flat[path] = value as Object;
    }
  }
  return flat;
}

Set<String> _placeholders(Object value) => {
  for (final text
      in value is Map ? value.values.cast<String>() : [value as String])
    for (final m in RegExp(r'\{(\w+)\}').allMatches(text)) m.group(1)!,
};

void main() {
  final en = _flatten(readTranslations('en'));
  final ar = _flatten(readTranslations('ar'));

  test('Arabic has exactly the English keys', () {
    expect(ar.keys.toSet(), en.keys.toSet());
  });

  test('no text is empty', () {
    for (final entry in <MapEntry<String, Object>>[
      ...en.entries,
      ...ar.entries,
    ]) {
      final value = entry.value;
      final texts = value is Map ? value.values : [value];
      expect(
        texts.every((t) => (t as String).trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
  });

  test('Arabic uses the same placeholders as English', () {
    for (final key in en.keys) {
      expect(_placeholders(ar[key]!), _placeholders(en[key]!), reason: key);
    }
  });

  test('plural texts cover the forms each language needs', () {
    for (final MapEntry(:key, :value) in en.entries) {
      if (value is! Map) continue;
      expect(value.keys, containsAll(['one', 'other']), reason: key);
      expect(
        (ar[key]! as Map).keys,
        containsAll(['zero', 'one', 'two', 'few', 'many', 'other']),
        reason: key,
      );
    }
  });

  test('every key used in the code exists', () {
    final used = <String>{};
    final pattern = RegExp(
      r"'([a-zA-Z]+(?:\.[a-zA-Z0-9_]+)+)'\s*\.(?:tr|plural)\(",
    );
    final domainKey = RegExp(r"'((?:validation|errors|media)\.[a-zA-Z0-9_]+)'");
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      used
        ..addAll(pattern.allMatches(source).map((m) => m.group(1)!))
        ..addAll(domainKey.allMatches(source).map((m) => m.group(1)!));
    }
    expect(used, isNotEmpty);
    expect(used.where((k) => !en.containsKey(k)), isEmpty);
  });

  test('keys built from enum values exist', () {
    final built = [
      for (final m in MuscleGroup.values) 'muscles.${m.name}',
      for (final g in TrainingGoal.values) 'trainingGoals.${g.name}',
      for (final t in GreetingTime.values) 'home.greeting.${t.name}',
      for (final w in ['height', 'weight', 'age']) 'onboarding.choose.$w',
    ];
    expect(built.where((k) => !en.containsKey(k)), isEmpty);
  });

  test('every placeholder in a domain message has a value', () {
    final args = Validators.messageArgs.keys.toSet();
    for (final MapEntry(:key, :value) in en.entries) {
      if (!key.startsWith('validation.') && !key.startsWith('errors.')) {
        continue;
      }
      // `name` is filled in by the failure itself.
      expect(
        _placeholders(value).difference({...args, 'name'}),
        isEmpty,
        reason: key,
      );
    }
  });
}
