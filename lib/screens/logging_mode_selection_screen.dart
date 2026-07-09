import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'individual_session_setup_screen.dart';
import 'training/drill_setup_screen.dart';
import 'unified_session_setup_screen.dart';
import '../services/feature_flag_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

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
      await Future.delayed(const Duration(milliseconds: 500));
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
          // Modal panel (dark surface)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppDecorations.radiusXl),
                topRight: Radius.circular(AppDecorations.radiusXl),
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
                            style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 20 / 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textSecondary,
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
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + subtitle
          Text(
            title,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 22 / 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
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
                color: AppColors.bgInverse,
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              ),
              child: Text(
                l10n.loggingChoose,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textInverse,
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
          color: AppColors.bgElevated,
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.loggingTrainingDrills,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 22 / 17,
                    ),
                  ),
                  Text(
                    l10n.loggingTrainingDrillsSubtitle,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
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
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              child: Text(
                l10n.loggingPro,
                style: AppTypography.ibm(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
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
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(AppDecorations.navBarRadius),
      ),
      child: Text(
        text,
        style: AppTypography.ibm(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
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
