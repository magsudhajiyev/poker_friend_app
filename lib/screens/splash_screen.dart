import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _navigated = false;

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

      if (mounted) setState(() => _initialized = true);

      controller.addListener(_onVideoProgress);
      await controller.play();
    } catch (e) {
      debugPrint('SplashScreen video error: $e');
      await Future.delayed(const Duration(seconds: 2));
      _navigate();
    }
  }

  void _onVideoProgress() {
    final c = _controller;
    if (c == null || _navigated) return;
    final duration = c.value.duration.inMilliseconds;
    final position = c.value.position.inMilliseconds;
    // Navigate when video is within 150ms of its end
    if (duration > 0 && position >= duration - 150) {
      _navigate();
    }
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF02050B),
      body: (_initialized && c != null)
          ? Center(
              child: SizedBox(
                width: screenWidth * 0.5,
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
