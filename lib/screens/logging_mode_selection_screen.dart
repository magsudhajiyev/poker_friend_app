import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'training/drill_setup_screen.dart';
import 'unified_session_setup_screen.dart';
import '../services/feature_flag_service.dart';
import '../widgets/single_hand/single_hand_flow.dart';
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

  /// "Log a hand" card: flag on, and never while the onboarding tour runs
  /// (the tour highlights the Full logging card).
  @visibleForTesting
  static bool singleHandCardVisible(
          {required bool flagOn, required bool tourActive}) =>
      flagOn && !tourActive;

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

  bool get _showSingleHandCard =>
      LoggingModeSelectionScreen.singleHandCardVisible(
        flagOn: FeatureFlagService.isEnabled(FeatureFlagService.singleHand),
        tourActive: OnboardingState.isOnboardingActive,
      );

  Future<void> _startSingleHand() async {
    final done = await SingleHandFlow.run(context);
    if (done && mounted) Navigator.pop(context);
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
          // Modal panel (dark surface), scrolls on short screens
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
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

                        // Log a hand entry (feature-flagged, hidden during the tour)
                        ValueListenableBuilder<int>(
                          valueListenable: FeatureFlagService.revision,
                          builder: (context, _, __) => _showSingleHandCard
                              ? Column(children: [
                                  const SizedBox(height: 16),
                                  _buildModeCard(
                                    title: l10n.singleHandCardTitle,
                                    subtitle: l10n.singleHandCardSubtitle,
                                    features: [
                                      l10n.singleHandFeature1,
                                      l10n.singleHandFeature2,
                                      l10n.singleHandFeature3,
                                    ],
                                    onChoose: _startSingleHand,
                                  ),
                                ])
                              : const SizedBox.shrink(),
                        ),

                        // Training Drills entry (premium, feature-flagged)
                        ValueListenableBuilder<int>(
                          valueListenable: FeatureFlagService.revision,
                          builder: (context, _, __) =>
                              FeatureFlagService.isEnabled(
                                      FeatureFlagService.trainingDrills)
                                  ? Column(children: [
                                      const SizedBox(height: 16),
                                      _buildModeCard(
                                        title: l10n.loggingTrainingDrills,
                                        subtitle:
                                            l10n.loggingTrainingDrillsSubtitle,
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
    return _ModeCard(
      key: key,
      title: title,
      subtitle: subtitle,
      features: features,
      badge: badge,
      chooseLabel: AppLocalizations.of(context).loggingChoose,
      onChoose: onChoose,
      chipBuilder: _buildChip,
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

/// Mode selection card — the whole surface is one tap target.
///
/// Micro-interactions on press:
/// - Card scales to 0.98 (spring settle on release).
/// - Chevron slides 4px right and fades label to full opacity.
/// - Haptic selection tick on release.
///
/// Together they make the card unmistakably tappable without needing a
/// dedicated button inside.
class _ModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> features;
  final String? badge;
  final String chooseLabel;
  final VoidCallback onChoose;
  final Widget Function(String) chipBuilder;

  const _ModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.chooseLabel,
    required this.onChoose,
    required this.chipBuilder,
    this.badge,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    const pressCurve = Curves.easeOut;
    const releaseCurve = Curves.elasticOut;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onChoose();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: Duration(milliseconds: _pressed ? 120 : 260),
        curve: _pressed ? pressCurve : releaseCurve,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            border: Border.all(
              color: _pressed
                  ? AppColors.accentPrimary.withOpacity(0.5)
                  : AppColors.borderStrong,
            ),
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
                      widget.title,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 22 / 17,
                      ),
                    ),
                  ),
                  if (widget.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius:
                            BorderRadius.circular(AppDecorations.pillRadius),
                      ),
                      child: Text(
                        widget.badge!,
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
                widget.subtitle,
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
                children: widget.features.map(widget.chipBuilder).toList(),
              ),
              const SizedBox(height: 16),
              // Trailing "Choose ›" affordance — chevron nudges + label
              // brightens on press.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _pressed
                          ? AppColors.accentPrimary
                          : AppColors.accentPrimary.withOpacity(0.85),
                      height: 20 / 15,
                    ),
                    child: Text(widget.chooseLabel),
                  ),
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(
                        _pressed ? 4.0 : 0.0, 0.0, 0.0),
                    child: SvgPicture.asset(
                      'assets/icons/CaretRight.svg',
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        AppColors.accentPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
