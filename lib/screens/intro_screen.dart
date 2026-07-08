import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../utils/user_facing_error.dart';
import 'auth_screen_experimental.dart';

class IntroScreen extends StatefulWidget {
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isStartingGuest = false;
  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Guest entry — anonymous auth; AuthWrapper's auth stream takes over
  /// (questions → Home → guided tour) without any navigation from here.
  Future<void> _startAsGuest() async {
    if (_isStartingGuest) return;
    setState(() => _isStartingGuest = true);
    try {
      await AuthService.signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingGuest = false);
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),

          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/main_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header with logo
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        l10n.onboardingFinalTable,
                        style: AppTypography.pageSubtitle(),
                      ),
                      const Spacer(),
                      // Skip button (hidden on last page)
                      if (_currentPage < _totalPages - 1)
                        GestureDetector(
                          onTap: () => _goToPage(_totalPages - 1),
                          child: Text(
                            l10n.onboardingSkip,
                            style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    children: [
                      _buildSlide(
                        title: l10n.onboardingTrackTitle,
                        subtitle: l10n.onboardingTrackSubtitle,
                      ),
                      _buildSlide(
                        title: l10n.onboardingKnowTitle,
                        subtitle: l10n.onboardingKnowSubtitle,
                      ),
                      _buildSlide(
                        title: l10n.onboardingClubsTitle,
                        subtitle: l10n.onboardingClubsSubtitle,
                      ),
                      _buildAuthPage(),
                    ],
                  ),
                ),

                // Page indicator dots
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.buttonPrimary
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            title,
            style: AppTypography.pageTitleLarge().copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.textDisabled,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildAuthPage() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            l10n.onboardingReadTitle,
            style: AppTypography.pageTitleLarge().copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingReadSubtitle,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.textDisabled,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),

          // Get Started Button (guest — no account needed)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isStartingGuest ? null : _startAsGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.bgPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
                elevation: 0,
              ),
              child: _isStartingGuest
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      l10n.introGetStarted,
                      style: AppTypography.buttonText().copyWith(fontSize: 16),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Create Account Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreenExperimental(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.whiteOverlay(opacity: 0.30),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
              ),
              child: Text(
                l10n.onboardingCreateAccount,
                style: AppTypography.buttonText(color: Colors.white).copyWith(
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Log In link
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreenExperimental(initialIsSignUp: false),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  l10n.onboardingLogIn,
                  style: AppTypography.ibm(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(flex: 1),
        ],
      ),
    );
  }
}
