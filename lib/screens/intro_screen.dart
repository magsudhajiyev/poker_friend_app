import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import 'auth_screen_experimental.dart';

class IntroScreen extends StatefulWidget {
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: AppColors.backgroundPaper,
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.whiteOverlay(opacity: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'P',
                            style: AppTypography.pageTitle().copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Final Table',
                        style: AppTypography.pageSubtitle(),
                      ),
                      const Spacer(),
                      // Skip button (hidden on last page)
                      if (_currentPage < _totalPages - 1)
                        GestureDetector(
                          onTap: () => _goToPage(_totalPages - 1),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8C8C8C),
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
                        title: 'TRACK EVERY\nHAND',
                        subtitle: 'Log actions, board cards, and results for every hand you play — live or after the session.',
                        icon: Icons.style_rounded,
                      ),
                      _buildSlide(
                        title: 'KNOW YOUR\nGAME',
                        subtitle: 'VPIP, PFR, 3-Bet, C-Bet and more — see your stats evolve in real time.',
                        icon: Icons.insights_rounded,
                      ),
                      _buildSlide(
                        title: 'PLAY AT\nCLUBS',
                        subtitle: 'Join live events, see rankings, and track your opponents across sessions.',
                        icon: Icons.groups_rounded,
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
                              ? const Color(0xFF89F1EC)
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
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF89F1EC).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF89F1EC), size: 32),
          ),
          const SizedBox(height: 24),
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
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8C8C8C),
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildAuthPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            'READ THE GAME\nLIKE A PRO',
            style: AppTypography.pageTitleLarge().copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create an account to start tracking your poker journey.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8C8C8C),
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),

          // Create Account Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreenExperimental(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.backgroundPaper,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
                elevation: 0,
              ),
              child: Text(
                'Create account',
                style: AppTypography.buttonText().copyWith(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Log In Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreenExperimental(initialIsSignUp: false),
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
                'Log in',
                style: AppTypography.buttonText(color: Colors.white).copyWith(
                  fontSize: 16,
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
