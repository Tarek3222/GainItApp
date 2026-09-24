import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/features/exercises/presentation/widgets/exercise_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../helpers/fake_video_player_platform.dart';

void main() {
  late FakeVideoPlayerPlatform platform;

  setUp(() {
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<void> pumpPlayer(WidgetTester tester, {bool show = true}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: show
                ? const ExerciseVideoPlayer(path: '/media/demo.mp4')
                : const SizedBox(),
          ),
        ),
      );

  Future<void> play(WidgetTester tester) async {
    await pumpPlayer(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Play video'));
    await tester.pump();
  }

  testWidgets('starts muted and plays on tap', (tester) async {
    await play(tester);

    expect(platform.calls, containsAllInOrder(['volume 0.0', 'play']));
    expect(find.bySemanticsLabel('Pause video'), findsOneWidget);
  });

  testWidgets('leaving the screen while playing throws nothing', (
    tester,
  ) async {
    await play(tester);

    // Remove the player while it plays (e.g. navigating back).
    await pumpPlayer(tester, show: false);
    await tester.pumpAndSettle();

    // Let the controller's asynchronous dispose finish.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(tester.takeException(), isNull);
    expect(platform.calls, containsAllInOrder(['play', 'dispose']));
  });

  testWidgets('a route pushed on top pauses playback', (tester) async {
    await play(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Edit')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(platform.calls.last, 'pause');
  });

  testWidgets('pausing by tap works and is reported to screen readers', (
    tester,
  ) async {
    await play(tester);

    await tester.tap(find.bySemanticsLabel('Pause video'));
    await tester.pump();

    expect(platform.calls.last, 'pause');
    expect(find.bySemanticsLabel('Play video'), findsOneWidget);
  });

  // Android's platform-view mode is not recommended (flutter#164899); the
  // Vulkan crash is avoided by Impeller's OpenGL ES backend instead.
  testWidgets(
    'videos use the recommended texture view',
    (tester) async {
      await pumpPlayer(tester);
      await tester.pumpAndSettle();

      expect(platform.viewTypes, [VideoViewType.textureView]);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  test('Android renders with Impeller on OpenGL ES, not Vulkan', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      matches(
        RegExp(
          r'android:name="io\.flutter\.embedding\.android\.ImpellerBackend"'
          r'\s*android:value="opengles"',
        ),
      ),
    );
  });
}
