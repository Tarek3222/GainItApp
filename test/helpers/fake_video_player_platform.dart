import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// In-memory video platform: every file "loads" as a 10 s, 640×360 clip and
/// records the calls made on it.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  final calls = <String>[];

  /// View type requested for each created player.
  final viewTypes = <VideoViewType>[];
  final _events = <int, StreamController<VideoEvent>>{};
  var _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    // Closed in dispose().
    // ignore: close_sinks
    _events[id] = StreamController<VideoEvent>();
    calls.add('create');
    viewTypes.add(options.viewType);
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    // Owned by _events and closed in dispose().
    // ignore: close_sinks
    final controller = _events[playerId]!;
    scheduleMicrotask(
      () => controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(640, 360),
        ),
      ),
    );
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume $volume');

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}
