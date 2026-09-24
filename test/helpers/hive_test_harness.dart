import 'dart:io';

import 'package:gainit/core/storage/hive_storage.dart';
import 'package:hive_ce/hive_ce.dart';

/// Opens a real Hive storage in an isolated temp directory per test.
class HiveTestHarness {
  late Directory _dir;
  late HiveStorage storage;

  Future<HiveStorage> setUp() async {
    _dir = await Directory.systemTemp.createTemp('gainit_test_');
    Hive.init(_dir.path);
    storage = await HiveStorage.open();
    return storage;
  }

  Future<void> tearDown() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (_dir.existsSync()) await _dir.delete(recursive: true);
  }
}
