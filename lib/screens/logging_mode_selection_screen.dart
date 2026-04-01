import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'individual_session_setup_screen.dart';

class LoggingModeSelectionScreen extends StatefulWidget {
  const LoggingModeSelectionScreen({super.key});

  @override
  State<LoggingModeSelectionScreen> createState() =>
      _LoggingModeSelectionScreenState();
}

class _LoggingModeSelectionScreenState
    extends State<LoggingModeSelectionScreen> {
  final GlobalKey _fullModeCardKey = GlobalKey(debugLabel: 'fullModeCard');
  final GlobalKey _individualModeCardKey =
      GlobalKey(debugLabel: 'individualModeCard');

  @override
  void initState() {
    super.initState();
    _scheduleOnboardingTour();
  }

  void _scheduleOnboardingTour() async {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 1) return;

    // Wait for keys to attach
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (_fullModeCardKey.currentContext != null) break;
    }

    if (!mounted || _fullModeCardKey.currentContext == null) return;
    LoggingModeTour(
      fullModeCardKey: _fullModeCardKey,
      individualModeCardKey: _individualModeCardKey,
    ).show(context);
  }

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Subtle teal gradient at top
          Positioned(
            top: -screenWidth * 0.3,
            right: -screenWidth * 0.25,
            child: Transform.scale(
              scaleX: 1.0,
              scaleY: 0.7,
              child: Container(
                width: screenWidth * 1.5,
                height: screenWidth * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [
                      Color(0xFF1A4A4A),
                      Color(0xFF133538).withOpacity(0.7),
                      Color(0xFF133538).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const OnboardingProgressBar(),
                // Header with title and close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose Mode',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.43,
                          height: 1.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Padding(
                                padding: const EdgeInsets.all(4.5),
                                child: _buildIcon(
                                  'icons/figma_icons/close.svg',
                                  15,
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Mode Selection Cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Full Logging Mode Card
                        _buildModeCard(
                          context: context,
                          key: _fullModeCardKey,
                          title: 'Full Logging Mode',
                          subtitle: 'Complete Session Tracking',
                          features: [
                            'Multi-hand session tracking',
                            'Real time statistics',
                            'Detailed hand history',
                            'Session analytics',
                          ],
                          onTap: () =>
                              _navigateToMode(context, LoggingMode.full),
                        ),

                        SizedBox(height: 16),

                        // Individual Logging Mode Card
                        _buildModeCard(
                          context: context,
                          key: _individualModeCardKey,
                          title: 'Individual Logging Mode',
                          subtitle: 'Single hand tracking',
                          features: [
                            'Single hand focus',
                            'Quick logging',
                            'Hand analysis',
                            'Instant results',
                          ],
                          onTap: () =>
                              _navigateToMode(context, LoggingMode.individual),
                        ),

                        SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: ''),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<String> features,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and subtitle section
          Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Color(0xFF89F1EC),
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.64,
                  ),
                ),
              ],
            ),
          ),

          // Separator line
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              height: 1,
              color: Color(0xFF1C1F21),
            ),
          ),

          // Features section
          Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Features header with info icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Features',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                    ),
                    _buildIcon(
                      'icons/figma_icons/info.svg',
                      24,
                      Color(0xFF89F1EC),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Feature list
                ...features
                    .map((feature) => Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '•  ',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 17,
                                  color: Color(0xFF8C8C8C),
                                  fontWeight: FontWeight.w400,
                                  height: 1.44,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: Color(0xFF8C8C8C),
                                    fontWeight: FontWeight.w400,
                                    height: 1.44,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),

          SizedBox(height: 34),

          // Start button
          Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF89F1EC),
                  borderRadius: BorderRadius.circular(110),
                ),
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Start',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      height: 24 / 17,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMode(BuildContext context, LoggingMode mode) {
    // Both modes now go to Session Setup first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualSessionSetupScreen(
          loggingMode: mode,
        ),
      ),
    );
  }
}

enum LoggingMode {
  full,
  individual,
}
