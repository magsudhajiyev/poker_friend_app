import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/looping_splash_logo.dart';
import 'auth_wrapper.dart';
import '../design_system/constants/colors.dart';

/// Launch screen: loops the logo animation until the app is ready.
///
/// "Ready" means Firebase Auth has resolved its initial state (so
/// AuthWrapper can route immediately) AND at least one full loop of the
/// animation has played. If auth takes longer, the logo keeps looping
/// instead of cutting to a blank screen.
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
    FirebaseAuth.instance.authStateChanges().first.then((_) {
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
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
