import '../../domain/entities/body_weight_entry.dart';
import '../../domain/validation/validators.dart';
import '../hive_storage.dart';
import '../storage_guard.dart';

class BodyWeightLocalDataSource {
  const BodyWeightLocalDataSource(this._storage);

  final HiveStorage _storage;

  /// Most recent first.
  List<BodyWeightEntry> entries() =>
      _storage.bodyWeights.values.toList()
        ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

  Future<void> save(BodyWeightEntry entry) async {
    ensureValid(Validators.bodyWeight(entry));
    await _storage.bodyWeights.put(entry.id, entry);
  }

  Future<void> delete(String id) => _storage.bodyWeights.delete(id);

  Stream<List<BodyWeightEntry>> watch() => watchTriggers(triggers, entries);

  List<ChangeTrigger> get triggers => [_storage.bodyWeights.watch];
}
