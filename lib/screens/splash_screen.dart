import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/looping_splash_logo.dart';
import '../services/auth_service.dart';
import 'auth_wrapper.dart';
import '../design_system/constants/colors.dart';

/// Launch screen: loops the logo animation until the app is ready.
///
/// "Ready" means Firebase Auth has resolved its initial state (so
/// AuthWrapper can route immediately) AND at least one full loop of the
/// animation has played. If auth takes longer, the logo keeps looping
/// instead of cutting to a blank screen.
///
/// While the logo plays, we pre-fetch the user document so that
/// AuthWrapper and HomeScreen can read cached data instead of making
/// 3-4 sequential Firestore reads of the same document.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _authResolved = false;
  bool _loopCompleted = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Wait for the first auth state event — after this, AuthWrapper can
    // render the correct screen without showing its own loading state.
    // As soon as auth resolves, pre-fetch the user document so later
    // screens don't need to read it again.
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null) {
        // Fire-and-forget: prefetch runs in parallel with the video loop.
        unawaited(AuthService.prefetchUserDocument());
      }
      _authResolved = true;
      _maybeNavigate();
    }).catchError((_) {
      _authResolved = true;
      _maybeNavigate();
    });

    // Safety net: never hold the user hostage if something hangs.
    Future.delayed(const Duration(seconds: 10), () {
      _authResolved = true;
      _loopCompleted = true;
      _maybeNavigate();
    });
  }

  void _onLoopCompleted() {
    _loopCompleted = true;
    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (_navigated || !mounted) return;
    if (!_authResolved || !_loopCompleted) return;
    _navigated = true;
    // Extend MaterialPageRoute to disable the slide animation so the
    // splash logo doesn't shift left during the transition. We must use
    // MaterialPageRoute (not PageRouteBuilder) because PageRouteBuilder
    // doesn't maintain child StreamBuilder state when routes above are
    // popped — see diary/2026-07-16-system-back-button-and-pageroute-reload-bug.md.
    Navigator.of(context).pushReplacement(
      _NoAnimationRoute(builder: (_) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: LoopingSplashLogo(onLoopCompleted: _onLoopCompleted),
    );
  }
}

/// MaterialPageRoute subclass with zero-duration transitions.
/// Preserves all MaterialPageRoute state-management behaviour (unlike
/// PageRouteBuilder) while eliminating the default slide animation.
class _NoAnimationRoute extends MaterialPageRoute<void> {
  _NoAnimationRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}
