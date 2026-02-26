import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import 'intro_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loggedUnexpectedLogout = false;
  bool _wasSignedIn = false;  // Track if user was ever signed in during this session
  bool _waitingForRecovery = false;  // Track if we're waiting for auth to recover

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        print('📍 AUTH: Stream state=${snapshot.connectionState}, hasData=${snapshot.hasData}, user=${snapshot.data?.uid?.substring(0, 8) ?? 'null'}');

        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('📍 AUTH: Connection waiting, showing loading');
          return _buildLoadingScreen(context);
        }

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          print('📍 AUTH: User signed in, showing HomeScreen');
          _loggedUnexpectedLogout = false;
          _wasSignedIn = true;  // Remember user was signed in
          _waitingForRecovery = false;
          AuthService.clearExplicitLogoutFlag();

          // Ensure user document exists (safety net for all users)
          AuthService.ensureUserDocument();

          // Process any pending deep link invitations
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DeepLinkService.processPendingInvitation();
          });
          return HomeScreen();
        }

        // User appears signed out - verify this is intentional
        // Check 1: If currentUser still exists but stream says null (transient issue)
        if (!AuthService.isExplicitLogout && AuthService.currentUser != null) {
          print('📍 AUTH: MISMATCH - stream null but currentUser exists, isExplicitLogout=${AuthService.isExplicitLogout}');
          return _buildLoadingScreen(context);
        }

        // Check 2: If user was signed in but now stream says null and it wasn't explicit
        // Wait briefly for auth to recover (might be transient network issue)
        if (_wasSignedIn && !AuthService.isExplicitLogout && !_waitingForRecovery) {
          print('📍 AUTH: Unexpected auth loss (was signed in), waiting 3s for recovery');
          _waitingForRecovery = true;

          // Wait up to 3 seconds for auth to recover
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _waitingForRecovery) {
              print('📍 AUTH: Recovery timeout, re-evaluating auth state');
              setState(() {
                _waitingForRecovery = false;
              });
            }
          });
          return _buildLoadingScreen(context);
        }

        // If we're still waiting for recovery, keep showing loading
        if (_waitingForRecovery) {
          return _buildLoadingScreen(context);
        }

        // Log unexpected logout for debugging (only once per session)
        if (!AuthService.isExplicitLogout && !_loggedUnexpectedLogout) {
          print('⚠️ AUTH: Unexpected logout detected - user did not explicitly sign out');
          print('📍 AUTH: _wasSignedIn=$_wasSignedIn, isExplicitLogout=${AuthService.isExplicitLogout}');
          _loggedUnexpectedLogout = true;
        }

        print('📍 AUTH: User not signed in, showing IntroScreen, isExplicitLogout=${AuthService.isExplicitLogout}');
        // Reset _wasSignedIn when showing intro screen
        _wasSignedIn = false;

        // User is not signed in
        return IntroScreen();
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'Poker Logger',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
