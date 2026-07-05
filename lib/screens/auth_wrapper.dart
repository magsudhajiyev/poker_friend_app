import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../services/subscription_service.dart';
import '../services/username_service.dart';
import '../services/onboarding_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/looping_splash_logo.dart';
import 'intro_screen.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_flow.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loggedUnexpectedLogout = false;
  bool _wasSignedIn = false;  // Track if user was ever signed in during this session
  bool _waitingForRecovery = false;  // Track if we're waiting for auth to recover
  bool _authTimedOut = false;  // Track if auth stream took too long to resolve
  Future<bool>? _usernameSetupFuture;  // Stored future to prevent re-creation on stream rebuilds
  Future<bool>? _onboardingFuture;    // Stored future for onboarding check
  Timer? _authTimeoutTimer;
  @override
  void initState() {
    super.initState();
    _startAuthTimeout();
  }

  @override
  void dispose() {
    _authTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startAuthTimeout() {
    _authTimeoutTimer?.cancel();
    _authTimedOut = false;
    _authTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _authTimedOut = true;
        });
      }
    });
  }

  /// Returns true if username setup is done (or was auto-claimed from web reservation).
  Future<bool> _checkUsernameSetup() async {
    // Ensure user document exists BEFORE checking username setup
    // (avoids race where doc doesn't exist yet → grandfathering returns true)
    await AuthService.ensureUserDocument();

    final completed = await UsernameService.hasCompletedUsernameSetup();
    debugPrint('📍 AUTH: hasCompletedUsernameSetup=$completed');
    if (completed) return true;

    // Look up web reservation by email — auto-claim and skip setup screen
    final email = AuthService.currentUser?.email;
    debugPrint('📍 AUTH: Checking web reservation for email=$email');
    if (email != null) {
      final reservedUsername = await UsernameService.getPendingClaimForEmail(email);
      debugPrint('📍 AUTH: Reserved username=$reservedUsername');
      if (reservedUsername != null) {
        final claimed = await UsernameService.claimUsername(reservedUsername);
        debugPrint('📍 AUTH: Auto-claim result=$claimed');
        if (claimed) return true;
      }
    }
    return false;
  }

  void _retryAuth() {
    setState(() {
      _authTimedOut = false;
    });
    _startAuthTimeout();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📍 AUTH_WRAPPER: build() called');
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        debugPrint('📍 AUTH: Stream state=${snapshot.connectionState}, hasData=${snapshot.hasData}, user=${snapshot.data?.uid?.substring(0, 8) ?? 'null'}');

        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('📍 AUTH: Connection waiting, timedOut=$_authTimedOut');
          if (_authTimedOut) {
            return _buildConnectionErrorScreen(context);
          }
          return _buildLoadingScreen(context);
        }

        // Auth resolved — cancel timeout
        _authTimeoutTimer?.cancel();

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          debugPrint('📍 AUTH: User signed in, showing HomeScreen');
          _loggedUnexpectedLogout = false;
          _wasSignedIn = true;  // Remember user was signed in
          _waitingForRecovery = false;
          AuthService.clearExplicitLogoutFlag();

          // Process any pending deep link invitations
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DeepLinkService.processPendingInvitation();
            // Associate RevenueCat user on app restart with existing session
            if (SubscriptionService.isInitialized) {
              SubscriptionService.loginUser(snapshot.data!.uid);
            }
          });

          // Reuse the same future across stream rebuilds to avoid re-running the check
          _usernameSetupFuture ??= _checkUsernameSetup();

          return FutureBuilder<bool>(
            future: _usernameSetupFuture,
            builder: (context, usernameSnapshot) {
              if (usernameSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen(context);
              }
              if (usernameSnapshot.data == true) {
                // Username done — check onboarding
                _onboardingFuture ??= OnboardingService.hasCompletedOnboarding();
                return FutureBuilder<bool>(
                  future: _onboardingFuture,
                  builder: (context, onboardingSnapshot) {
                    if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingScreen(context);
                    }
                    if (onboardingSnapshot.data == true) {
                      return HomeScreen();
                    }
                    return const OnboardingFlow(skipNickname: true);
                  },
                );
              }
              // Username not set — onboarding flow handles nickname claim
              return const OnboardingFlow(skipNickname: false);
            },
          );
        }

        // User appears signed out - verify this is intentional
        // Check 1: If currentUser still exists but stream says null (transient issue)
        if (!AuthService.isExplicitLogout && AuthService.currentUser != null) {
          debugPrint('📍 AUTH: MISMATCH - stream null but currentUser exists, isExplicitLogout=${AuthService.isExplicitLogout}');
          return _buildLoadingScreen(context);
        }

        // Check 2: If user was signed in but now stream says null and it wasn't explicit
        // Wait briefly for auth to recover (might be transient network issue)
        if (_wasSignedIn && !AuthService.isExplicitLogout && !_waitingForRecovery) {
          debugPrint('📍 AUTH: Unexpected auth loss (was signed in), waiting 3s for recovery');
          _waitingForRecovery = true;

          // Wait up to 3 seconds for auth to recover
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _waitingForRecovery) {
              debugPrint('📍 AUTH: Recovery timeout, re-evaluating auth state');
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
          debugPrint('⚠️ AUTH: Unexpected logout detected - user did not explicitly sign out');
          debugPrint('📍 AUTH: _wasSignedIn=$_wasSignedIn, isExplicitLogout=${AuthService.isExplicitLogout}');
          _loggedUnexpectedLogout = true;
        }

        debugPrint('📍 AUTH: User not signed in, showing IntroScreen, isExplicitLogout=${AuthService.isExplicitLogout}');
        // Reset state when showing intro screen
        _wasSignedIn = false;
        _usernameSetupFuture = null;
        _onboardingFuture = null;

        // User is not signed in
        return IntroScreen();
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    // Keep the logo animation looping while auth/user data loads, instead
    // of cutting to a blank screen after the splash plays once.
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: LoopingSplashLogo(),
    );
  }

  Widget _buildConnectionErrorScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.textDisabled,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.authConnectionIssue,
                style: AppTypography.ibm(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.authConnectionIssueBody,
                style: AppTypography.ibm(
                  fontSize: 15,
                  color: AppColors.textDisabled,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _retryAuth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                    border: Border.all(
                      color: AppColors.buttonPrimary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    l10n.authTryAgain,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.buttonPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
