import '../../domain/validation/validators.dart';
import '../hive_storage.dart';
import '../storage_guard.dart';

/// v3: exercises can have several photos. Moves the old single photo
/// (`imagePath`) to the front of `imagePaths`.
Future<void> migrateExerciseImagesToList(HiveStorage storage) async {
  final updated = {
    for (final e in storage.exercises.values)
      if (e.imagePath case final legacy?)
        e.id: e.copyWith(
          imagePaths: [legacy, ...e.imagePaths.where((p) => p != legacy)],
          clearLegacyImage: true,
        ),
  };
  for (final e in updated.values) {
    ensureValid(Validators.exercise(e));
  }
  if (updated.isNotEmpty) await storage.exercises.putAll(updated);
}
