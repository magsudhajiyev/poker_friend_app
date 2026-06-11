import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The splash logo animation, played muted on a continuous loop.
///
/// Used by SplashScreen at launch and by AuthWrapper's loading states so
/// the logo keeps animating until the app's data is actually ready,
/// instead of cutting to a blank screen after one play-through.
class LoopingSplashLogo extends StatefulWidget {
  /// Called every time the animation completes a full loop.
  final VoidCallback? onLoopCompleted;

  const LoopingSplashLogo({super.key, this.onLoopCompleted});

  @override
  State<LoopingSplashLogo> createState() => LoopingSplashLogoState();
}

class LoopingSplashLogoState extends State<LoopingSplashLogo> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.asset('assets/splash.mp4');
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      controller.addListener(_onProgress);
      await controller.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('LoopingSplashLogo video error: $e');
      // Fall back to reporting loop completions on a timer so callers
      // waiting for a loop never hang.
      if (widget.onLoopCompleted != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) widget.onLoopCompleted?.call();
        });
      }
    }
  }

  void _onProgress() {
    final c = _controller;
    if (c == null) return;
    final position = c.value.position;
    final duration = c.value.duration;

    // A loop completed when the position wraps back toward zero, or when
    // we're within 150ms of the end (covers the non-wrapping last frame).
    final wrapped = position < _lastPosition;
    final nearEnd = duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 150 &&
        _lastPosition.inMilliseconds < duration.inMilliseconds - 150;
    if (wrapped || nearEnd) {
      widget.onLoopCompleted?.call();
    }
    _lastPosition = position;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final screenWidth = MediaQuery.of(context).size.width;
    if (!_initialized || c == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: screenWidth * 0.5,
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}
