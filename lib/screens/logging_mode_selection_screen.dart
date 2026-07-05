import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'individual_session_setup_screen.dart';
import 'training/drill_setup_screen.dart';
import 'unified_session_setup_screen.dart';
import '../services/feature_flag_service.dart';

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

  void _scheduleOnboardingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || _fullModeCardKey.currentContext == null) return;
      LoggingModeTour(
        fullModeCardKey: _fullModeCardKey,
        individualModeCardKey: _individualModeCardKey,
      ).show(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          OnboardingProgressBar(),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // White modal panel
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: centered title + X
                    Row(
                      children: [
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            l10n.loggingModeChooseMode,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0C0C0C),
                              height: 20 / 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFFB9B9B9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Full Logging Mode card
                    _buildModeCard(
                      key: _fullModeCardKey,
                      title: l10n.loggingModeFullTitle,
                      subtitle: l10n.loggingModeFullSubtitle,
                      features: [
                        l10n.loggingModeFullFeature1,
                        l10n.loggingModeFullFeature2,
                        l10n.loggingModeFullFeature3,
                        l10n.loggingModeFullFeature4,
                      ],
                      onChoose: () => _navigateToMode(context, LoggingMode.full),
                    ),

                    const SizedBox(height: 16),

                    // Individual Logging Mode card
                    _buildModeCard(
                      key: _individualModeCardKey,
                      title: l10n.loggingModeIndividualTitle,
                      subtitle: l10n.loggingModeIndividualSubtitle,
                      features: [
                        l10n.loggingModeIndividualFeature1,
                        l10n.loggingModeIndividualFeature2,
                        l10n.loggingModeIndividualFeature3,
                        l10n.loggingModeIndividualFeature4,
                      ],
                      onChoose: () => _navigateToMode(context, LoggingMode.individual),
                    ),

                    // Training Drills entry (premium, feature-flagged)
                    ValueListenableBuilder<int>(
                      valueListenable: FeatureFlagService.revision,
                      builder: (context, _, __) => FeatureFlagService
                              .isEnabled(FeatureFlagService.trainingDrills)
                          ? Column(children: [
                              const SizedBox(height: 16),
                              _buildTrainingRow(context),
                            ])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required List<String> features,
    required VoidCallback onChoose,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        border: Border.all(color: const Color(0xFFEFEFEF)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + subtitle
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C0C0C),
              height: 22 / 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF0C0C0C),
              height: 22 / 15,
            ),
          ),
          const SizedBox(height: 16),

          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features.map(_buildChip).toList(),
          ),
          const SizedBox(height: 24),

          // Choose button
          GestureDetector(
            onTap: onChoose,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.loggingChoose,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 20 / 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DrillSetupScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFD),
          border: Border.all(color: const Color(0xFFEFEFEF)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.loggingTrainingDrills,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0C0C0C),
                      height: 22 / 17,
                    ),
                  ),
                  Text(
                    l10n.loggingTrainingDrillsSubtitle,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B6B6B),
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                l10n.loggingPro,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: const Color(0xFF89F1EC),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFFB9B9B9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2C2C2E)),
        borderRadius: BorderRadius.circular(70),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF0C0C0C),
          height: 20 / 13,
        ),
      ),
    );
  }

  void _navigateToMode(BuildContext context, LoggingMode mode) {
    if (OnboardingState.isOnboardingActive) {
      OnboardingState.isIndividualMode = (mode == LoggingMode.individual);
    }
    if (mode == LoggingMode.full) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnifiedSessionSetupScreen(),
        ),
      );
    } else {
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
}

enum LoggingMode {
  full,
  individual,
}
