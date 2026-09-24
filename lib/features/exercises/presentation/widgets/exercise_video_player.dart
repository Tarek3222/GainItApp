import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_tokens.dart';

/// Plays a local exercise video. Tap to play or pause; it loops. Starts
/// muted and pauses when the screen is covered or the app is backgrounded.
class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({super.key, required this.path});

  final String path;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  VideoPlayerController? _controller;
  late final AppLifecycleListener _lifecycle;
  bool _failed = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _pause);
    _open();
  }

  void _pause() {
    final controller = _controller;
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tickers are disabled when another route (e.g. Edit) covers this one.
    if (!TickerMode.valuesOf(context).enabled) _pause();
  }

  @override
  void deactivate() {
    _pause();
    super.deactivate();
  }

  @override
  void didUpdateWidget(ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller?.dispose();
      _open();
    }
  }

  void _open() {
    _failed = false;
    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;
    controller
        .initialize()
        .then((_) async {
          await controller.setLooping(true);
          await controller.setVolume(_muted ? 0 : 1);
          if (mounted && identical(controller, _controller)) setState(() {});
        })
        .catchError((Object _) {
          if (mounted && identical(controller, _controller)) {
            setState(() => _failed = true);
          }
        });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleSound() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return const _VideoMessage(
        icon: Icons.videocam_off_outlined,
        text: 'This video cannot be played.',
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Semantics(
      button: true,
      label: controller.value.isPlaying ? 'Pause video' : 'Play video',
      child: GestureDetector(
        onTap: _toggle,
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                if (!controller.value.isPlaying)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        Icons.play_arrow,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                  ),
                ),
                PositionedDirectional(
                  top: AppSpacing.xs,
                  end: AppSpacing.xs,
                  child: IconButton.filledTonal(
                    tooltip: _muted ? 'Turn sound on' : 'Mute',
                    onPressed: _toggleSound,
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoMessage extends StatelessWidget {
  const _VideoMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), Text(text)],
      ),
    ),
  );
}
