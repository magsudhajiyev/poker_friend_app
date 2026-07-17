import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../design_system/constants/colors.dart';

/// The splash logo animation, played muted on a continuous loop.
///
/// A **shared** [VideoPlayerController] is initialized once and reused across
/// every instance (SplashScreen → AuthWrapper → HomeScreen) so the video never
/// stutters or re-initializes during screen transitions. Call
/// [LoopingSplashLogo.releaseShared] after the loading phase is over to free
/// the video memory.
class LoopingSplashLogo extends StatefulWidget {
  /// Called every time the animation completes a full loop.
  final VoidCallback? onLoopCompleted;

  const LoopingSplashLogo({super.key, this.onLoopCompleted});

  // ── Shared controller ──────────────────────────────────────────────

  static VideoPlayerController? _shared;
  static Future<void>? _initFuture;
  static bool _ready = false;

  /// Kick off initialization as early as possible (can be called from main).
  static Future<void> warmUp() => _ensureInit();

  /// Release the shared controller once the loading phase is done.
  static void releaseShared() {
    _shared?.dispose();
    _shared = null;
    _initFuture = null;
    _ready = false;
  }

  static Future<void> _ensureInit() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  static Future<void> _doInit() async {
    final c = VideoPlayerController.asset('assets/splash.mp4');
    _shared = c;
    try {
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      _ready = true;
    } catch (e) {
      debugPrint('LoopingSplashLogo video error: $e');
    }
  }

  @override
  State<LoopingSplashLogo> createState() => LoopingSplashLogoState();
}

class LoopingSplashLogoState extends State<LoopingSplashLogo> {
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  Future<void> _attach() async {
    await LoopingSplashLogo._ensureInit();
    final c = LoopingSplashLogo._shared;
    if (c == null) {
      // Video failed — fire the loop callback on a timer so callers
      // waiting for a loop never hang.
      if (widget.onLoopCompleted != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) widget.onLoopCompleted?.call();
        });
      }
      return;
    }
    c.addListener(_onProgress);
    if (mounted) setState(() {});
  }

  void _onProgress() {
    final c = LoopingSplashLogo._shared;
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
    LoopingSplashLogo._shared?.removeListener(_onProgress);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = LoopingSplashLogo._shared;
    final screenWidth = MediaQuery.of(context).size.width;
    if (!LoopingSplashLogo._ready || c == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: screenWidth * 0.5,
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          // Paint AppColors.paper behind the video so the video's own
          // background (slightly different black) blends seamlessly
          // with the scaffold.
          child: ColoredBox(
            color: AppColors.paper,
            child: VideoPlayer(c),
          ),
        ),
      ),
    );
  }
}
