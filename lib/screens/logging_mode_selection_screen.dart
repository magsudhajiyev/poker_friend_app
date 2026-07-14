import 'dart:ui';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'training/drill_setup_screen.dart';
import 'unified_session_setup_screen.dart';
import '../services/feature_flag_service.dart';
import '../design_system/components/sheets/sheet_header.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class LoggingModeSelectionScreen extends StatefulWidget {
  const LoggingModeSelectionScreen({super.key});

  /// Canonical route for opening the Choose Mode sheet — slides up from
  /// bottom over a blurred backdrop. Used by the bottom-nav FAB and any
  /// other "start a new session" call site (e.g. the Recent Sessions
  /// empty-state "Add New" pill).
  static Route<T> route<T>() {
    return PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const LoggingModeSelectionScreen(),
      transitionsBuilder: (_, animation, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));
        return Stack(
          children: [
            FadeTransition(
              opacity: animation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),
            SlideTransition(position: slide, child: child),
          ],
        );
      },
    );
  }

  @override
  State<LoggingModeSelectionScreen> createState() =>
      _LoggingModeSelectionScreenState();
}

class _LoggingModeSelectionScreenState
    extends State<LoggingModeSelectionScreen> {
  final GlobalKey _fullModeCardKey = GlobalKey(debugLabel: 'fullModeCard');

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
                    // Header: title + glass X
                    SheetHeader(
                      title: l10n.loggingModeChooseMode,
                      onClose: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),

                    // Logging Mode card
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
                      onChoose: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const UnifiedSessionSetupScreen(),
                          ),
                        );
                      },
                    ),

                    // Training Drills entry (premium, feature-flagged)
                    ValueListenableBuilder<int>(
                      valueListenable: FeatureFlagService.revision,
                      builder: (context, _, __) => FeatureFlagService
                              .isEnabled(FeatureFlagService.trainingDrills)
                          ? Column(children: [
                              const SizedBox(height: 16),
                              _buildModeCard(
                                title: l10n.loggingTrainingDrills,
                                subtitle: l10n.loggingTrainingDrillsSubtitle,
                                features: [
                                  l10n.loggingTrainingDrillsFeature1,
                                  l10n.loggingTrainingDrillsFeature2,
                                  l10n.loggingTrainingDrillsFeature3,
                                ],
                                badge: l10n.loggingPro,
                                onChoose: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const DrillSetupScreen()),
                                  );
                                },
                              ),
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
    String? badge,
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
          // Title + optional badge
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 22 / 17,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius:
                        BorderRadius.circular(AppDecorations.pillRadius),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.ibm(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
            ],
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
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              ),
              child: Text(
                l10n.loggingChoose,
                textAlign: TextAlign.center,
                style: AppTypography.ibm(
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
}
