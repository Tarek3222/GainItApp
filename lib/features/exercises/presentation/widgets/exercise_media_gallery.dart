import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../domain/entities/exercise_details.dart';
import 'exercise_video_player.dart';

sealed class _Slide {
  const _Slide();

  /// Stable identity, so a slide keeps its state when others are added or
  /// removed around it.
  String get id;
}

final class _VideoSlide extends _Slide {
  const _VideoSlide(this.path);

  final String path;

  @override
  String get id => 'video:$path';
}

final class _ImageSlide extends _Slide {
  const _ImageSlide(this.image, {required this.number, required this.total});

  final ExerciseImage image;

  /// 1-based position among the photos, for screen readers.
  final int number;
  final int total;

  @override
  String get id => 'photo:${image.fileName}';
}

/// The exercise's video and photos in one horizontal slider, sized to the
/// screen (about a quarter of its height, 180–300 px). Portrait and
/// landscape media both fit inside the frame.
class ExerciseMediaGallery extends StatefulWidget {
  const ExerciseMediaGallery({
    super.key,
    required this.details,
    required this.editable,
    required this.onAddImage,
    required this.onAddVideo,
    required this.onRemoveImage,
    required this.onRemoveVideo,
  });

  final ExerciseDetails details;
  final bool editable;
  final VoidCallback onAddImage;
  final VoidCallback onAddVideo;
  final ValueChanged<String> onRemoveImage;
  final VoidCallback onRemoveVideo;

  /// Height of the slider for a screen of [screenHeight].
  static double heightFor(double screenHeight) =>
      (screenHeight * 0.26).clamp(180.0, 300.0);

  @override
  State<ExerciseMediaGallery> createState() => _ExerciseMediaGalleryState();
}

class _ExerciseMediaGalleryState extends State<ExerciseMediaGallery> {
  late final PageController _pages;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static List<_Slide> _slidesOf(ExerciseDetails details) {
    final images = details.images;
    return [
      if (details.videoFile case final video?) _VideoSlide(video),
      for (final (i, image) in images.indexed)
        _ImageSlide(image, number: i + 1, total: images.length),
    ];
  }

  List<_Slide> get _slides => _slidesOf(widget.details);

  @override
  void didUpdateWidget(ExerciseMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = _slidesOf(oldWidget.details);
    final after = _slides;
    final oldIds = {for (final s in before) s.id};
    final added = [
      for (final (i, s) in after.indexed)
        if (!oldIds.contains(s.id)) i,
    ];
    if (added.isNotEmpty) {
      // Show what the user just added.
      _goTo(added.last);
    } else if (_page > after.length - 1 && after.isNotEmpty) {
      // The last slide was removed: stay on the new last one.
      _goTo(after.length - 1);
    }
  }

  void _goTo(int page) {
    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(page);
    });
  }

  Future<void> _confirmRemove(_Slide slide) async {
    final isVideo = slide is _VideoSlide;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVideo ? 'Remove video?' : 'Remove photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.semanticColors.danger,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    switch (slide) {
      case _VideoSlide():
        widget.onRemoveVideo();
      case _ImageSlide(:final image):
        widget.onRemoveImage(image.fileName);
    }
  }

  void _openPhotos(ExerciseImage tapped) {
    final images = widget.details.images;
    showDialog<void>(
      context: context,
      builder: (_) =>
          _PhotoViewer(images: images, initialIndex: images.indexOf(tapped)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slides = _slides;
    final height = ExerciseMediaGallery.heightFor(
      MediaQuery.sizeOf(context).height,
    );
    final photoCount = widget.details.images.length;
    final canAddPhoto = photoCount < Validators.maxExerciseImages;
    final hasVideo = widget.details.videoFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: ColoredBox(
              color: context.semanticColors.elevated,
              child: slides.isEmpty
                  ? _EmptyMedia(editable: widget.editable)
                  : PageView.builder(
                      controller: _pages,
                      itemCount: slides.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      // Keyed slides keep their state (the video's position)
                      // when slides are added or removed before them.
                      findChildIndexCallback: (key) {
                        final index = slides.indexWhere(
                          (s) => ValueKey(s.id) == key,
                        );
                        return index == -1 ? null : index;
                      },
                      itemBuilder: (context, index) => _SlideView(
                        key: ValueKey(slides[index].id),
                        slide: slides[index],
                        active: index == _page,
                        onOpen: _openPhotos,
                        onRemove: widget.editable
                            ? () => _confirmRemove(slides[index])
                            : null,
                      ),
                    ),
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _Dots(count: slides.length, current: _page),
        ],
        if (widget.editable) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: canAddPhoto ? widget.onAddImage : null,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  'Add photo ($photoCount/${Validators.maxExerciseImages})',
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onAddVideo,
                icon: const Icon(Icons.video_call_outlined),
                label: Text(hasVideo ? 'Replace video' : 'Add video'),
              ),
            ],
          ),
          if (!canAddPhoto)
            Text(
              'Photo limit reached. Remove one to add another.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _SlideView extends StatefulWidget {
  const _SlideView({
    super.key,
    required this.slide,
    required this.active,
    required this.onOpen,
    this.onRemove,
  });

  final _Slide slide;

  /// The slide currently on screen.
  final bool active;
  final ValueChanged<ExerciseImage> onOpen;
  final VoidCallback? onRemove;

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView>
    with AutomaticKeepAliveClientMixin {
  // The video stays alive while other slides are shown, so swiping back
  // doesn't reload it or lose its position and sound setting.
  @override
  bool get wantKeepAlive => widget.slide is _VideoSlide;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final slide = widget.slide;
    final onOpen = widget.onOpen;
    final content = switch (slide) {
      _VideoSlide(:final path) => ColoredBox(
        color: Colors.black,
        child: ExerciseVideoPlayer(path: path, active: widget.active),
      ),
      _ImageSlide(:final image, :final number, :final total) => Semantics(
        button: true,
        label: 'Photo $number of $total. Tap to view full screen.',
        child: GestureDetector(
          onTap: () => onOpen(image),
          child: Image.file(
            File(image.path),
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    };
    final remove = widget.onRemove;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (remove != null)
          PositionedDirectional(
            top: AppSpacing.xs,
            start: AppSpacing.xs,
            child: IconButton.filledTonal(
              tooltip: switch (slide) {
                _VideoSlide() => 'Remove video',
                _ImageSlide(:final number) => 'Remove photo $number',
              },
              onPressed: remove,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
  }
}

class _EmptyMedia extends StatelessWidget {
  const _EmptyMedia({required this.editable});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final muted = context.semanticColors.mutedText;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 40, color: muted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            editable ? 'Add photos or a video of your form' : 'No media',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Item ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppDurations.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen photos with pinch-to-zoom and swiping between them. While a
/// photo is zoomed in, dragging pans it instead of changing photos.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.images, required this.initialIndex});

  final List<ExerciseImage> images;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages;
  late final TransformationController _zoom;
  bool _zoomed = false;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pages = PageController(initialPage: _page);
    _zoom = TransformationController()..addListener(_onZoom);
  }

  @override
  void dispose() {
    _zoom
      ..removeListener(_onZoom)
      ..dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onZoom() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Decode at about twice the screen width so zooming stays sharp without
    // holding full-resolution photos in memory.
    final decodeWidth = (media.size.width * media.devicePixelRatio * 2).round();
    final total = widget.images.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: total,
            onPageChanged: (i) {
              _zoom.value = Matrix4.identity();
              setState(() => _page = i);
            },
            itemBuilder: (context, index) => Semantics(
              image: true,
              label: 'Photo ${index + 1} of $total',
              child: InteractiveViewer(
                // Only the visible photo shares the zoom controller.
                transformationController: index == _page ? _zoom : null,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(widget.images[index].path),
                    fit: BoxFit.contain,
                    cacheWidth: decodeWidth,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: IconButton(
                tooltip: 'Close',
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
