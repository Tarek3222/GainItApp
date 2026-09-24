import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/features/exercises/domain/entities/exercise_details.dart';
import 'package:gainit/features/exercises/presentation/widgets/exercise_media_gallery.dart';
import 'package:gainit/features/exercises/presentation/widgets/exercise_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../helpers/fake_video_player_platform.dart';

void main() {
  final curl = Exercise(
    id: 'ex_curl',
    name: 'Curl',
    primaryMuscle: MuscleGroup.biceps,
    category: ExerciseCategory.isolation,
    createdAt: DateTime(2026),
  );

  ExerciseDetails details({int photos = 0, bool video = false}) =>
      ExerciseDetails(
        exercise: curl,
        usedInDays: const [],
        videoFile: video ? '/media/demo.mp4' : null,
        images: [
          for (var i = 0; i < photos; i++)
            ExerciseImage(fileName: '$i.jpg', path: '/media/$i.jpg'),
        ],
      );

  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());

  Future<List<String>> pump(
    WidgetTester tester,
    ExerciseDetails d, {
    Size screen = const Size(400, 800),
    List<String>? into,
  }) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final events = into ?? <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseMediaGallery(
              details: d,
              editable: true,
              onAddImage: () => events.add('add image'),
              onAddVideo: () => events.add('add video'),
              onRemoveImage: (name) => events.add('remove $name'),
              onRemoveVideo: () => events.add('remove video'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return events;
  }

  test('the slider height follows the screen within 180–300 px', () {
    expect(ExerciseMediaGallery.heightFor(600), 180);
    expect(ExerciseMediaGallery.heightFor(900), closeTo(234, 0.01));
    expect(ExerciseMediaGallery.heightFor(1400), 300);
  });

  testWidgets('the frame uses the responsive height, not the video shape', (
    tester,
  ) async {
    await pump(tester, details(video: true), screen: const Size(400, 900));

    final frame = tester.getSize(find.byType(PageView));
    expect(frame.height, closeTo(234, 0.01));
  });

  testWidgets('the video comes first, then the photos, with page dots', (
    tester,
  ) async {
    await pump(tester, details(video: true, photos: 2));

    expect(find.byType(ExerciseVideoPlayer), findsOneWidget);
    expect(find.bySemanticsLabel('Item 1 of 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Item 2 of 3'), findsOneWidget);
    expect(find.byTooltip('Remove photo 1'), findsOneWidget);
  });

  testWidgets('removing asks first, then reports the photo', (tester) async {
    final events = await pump(tester, details(photos: 2));

    await tester.tap(find.byTooltip('Remove photo 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(events, ['remove 0.jpg']);
  });

  testWidgets('adding a photo is disabled at 10 photos', (tester) async {
    await pump(tester, details(photos: 10));

    final add = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Add photo (10/10)'),
    );
    expect(add.onPressed, isNull);
    expect(find.textContaining('Photo limit reached'), findsOneWidget);
  });

  testWidgets('with no media it invites adding some', (tester) async {
    final events = await pump(tester, details());

    expect(find.text('Add photos or a video of your form'), findsOneWidget);
    await tester.tap(find.text('Add video'));

    expect(events, ['add video']);
  });

  String dots(WidgetTester tester) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((s) => s.properties.label ?? '')
      .firstWhere((l) => l.startsWith('Item '), orElse: () => '');

  testWidgets('a newly added photo is shown straight away', (tester) async {
    await pump(tester, details(photos: 1));

    await pump(tester, details(photos: 2));

    expect(dots(tester), 'Item 2 of 2');
  });

  testWidgets('removing the last slide while on it stays in range', (
    tester,
  ) async {
    await pump(tester, details(photos: 3));
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(dots(tester), 'Item 3 of 3');

    await pump(tester, details(photos: 2));

    expect(dots(tester), 'Item 2 of 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the video keeps playing state when swiped away and back', (
    tester,
  ) async {
    final platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    await pump(tester, details(video: true, photos: 1));
    await tester.tap(find.bySemanticsLabel('Play video'));
    await tester.pump();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    // Paused when not visible, but not disposed and re-created.
    expect(platform.calls.last, 'pause');
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(platform.calls.where((c) => c == 'create'), hasLength(1));
    expect(platform.calls, isNot(contains('dispose')));
  });

  testWidgets('tapping a photo opens the viewer on that photo', (tester) async {
    await pump(tester, details(photos: 3));
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('^Photo 2 of 3. Tap')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Photo 2 of 3'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
