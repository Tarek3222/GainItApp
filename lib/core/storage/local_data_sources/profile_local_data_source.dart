import '../../domain/entities/user_profile.dart';
import '../../domain/validation/validators.dart';
import '../hive_storage.dart';
import '../settings_keys.dart';
import '../storage_guard.dart';

class ProfileLocalDataSource {
  const ProfileLocalDataSource(this._storage);

  final HiveStorage _storage;

  UserProfile? profile() => _storage.profile.get(kProfileKey);

  Future<void> save(UserProfile profile) async {
    ensureValid(Validators.profile(profile));
    await _storage.profile.put(kProfileKey, profile);
  }

  Stream<UserProfile?> watch() => watchTriggers(triggers, profile);

  List<ChangeTrigger> get triggers => [_storage.profile.watch];
}
