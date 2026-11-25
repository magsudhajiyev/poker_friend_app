import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import 'training/drill_setup_screen.dart';
import 'unified_session_setup_screen.dart';
import '../services/feature_flag_service.dart';
import '../widgets/single_hand/single_hand_flow.dart';
import '../services/live_session_logic.dart';
import '../utils/running_session_label.dart';
import '../widgets/running_session_guard.dart';
import 'tracked_session_setup_screen.dart';
import '../design_system/components/sheets/sheet_header.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';

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

  /// "Track a session" card: flag on, and never while the tour runs.
  @visibleForTesting
  static bool trackedSessionCardVisible(
          {required bool flagOn, required bool tourActive}) =>
      flagOn && !tourActive;

  @override
  State<LoggingModeSelectionScreen> createState() =>
      _LoggingModeSelectionScreenState();
}

class _LoggingModeSelectionScreenState
    extends State<LoggingModeSelectionScreen> {
  final GlobalKey _fullModeCardKey = GlobalKey(debugLabel: 'fullModeCard');

  /// Session that runs right now, for the top banner (never during the tour).
  LiveSessionRecord? _running;

  @override
  void initState() {
    super.initState();
    _scheduleOnboardingTour();
    _loadRunning();
  }

  Future<void> _loadRunning() async {
    if (OnboardingState.isOnboardingActive) return;
    try {
      final r = await RunningSessionGuard.current();
      if (mounted) setState(() => _running = r);
    } catch (_) {
      // The banner is a convenience; the gate still guards the rows.
    }
  }

  Future<void> _goToRunning() async {
    final r = _running;
    if (r == null) return;
    await RunningSessionGuard.goTo(Navigator.of(context), r);
    if (mounted) _loadRunning();
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

  bool get _showTrackedCard =>
      LoggingModeSelectionScreen.trackedSessionCardVisible(
        flagOn: FeatureFlagService.trackedSessionEnabled,
        tourActive: OnboardingState.isOnboardingActive,
      );

  /// A session may only start when none runs: the warning comes BEFORE any
  /// setup screen (never during the tour). No "continue anyway".
  Future<bool> _mayStartSession() async {
    if (OnboardingState.isOnboardingActive) return true;
    final free = await RunningSessionGuard.ensureFree(context);
    return free && mounted;
  }

  Future<void> _startTrackedSession() async {
    if (!await _mayStartSession()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrackedSessionSetupScreen()),
    );
  }

  Future<void> _startFullLogging() async {
    if (!await _mayStartSession()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UnifiedSessionSetupScreen()),
    );
  }

  Future<void> _startSingleHand() async {
    final done = await SingleHandFlow.run(context);
    if (done && mounted) Navigator.pop(context);
  }

  void _openDrills() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DrillSetupScreen()),
      );

  static const double _maxContentWidth = 560;

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
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9),
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
                // heightFactor 1: hug the content (a plain Center would fill the
                // whole max height and leave gaps above and below the rows).
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md,
                          AppSpacing.xl),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SheetHeader(
                              title: l10n.loggingModeChooseMode,
                              onClose: () => Navigator.pop(context),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ValueListenableBuilder<int>(
                              valueListenable: FeatureFlagService.revision,
                              builder: (context, _, __) => _list(l10n),
                            ),
                          ],
                        ),
                      ),
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

  Widget _list(AppLocalizations l10n) {
    final drills = FeatureFlagService.isEnabled(FeatureFlagService.trainingDrills);
    final rows = <Widget>[
      if (_showSingleHandCard)
        _ModeRow(
          iconAsset: 'assets/icons/HandSwipeRight.svg',
          title: l10n.singleHandCardTitle,
          subtitle: l10n.singleHandCardSubtitle,
          onTap: _startSingleHand,
        ),
      if (_showTrackedCard)
        _ModeRow(
          iconAsset: 'assets/icons/ClockUser.svg',
          title: l10n.trackedCardTitle,
          subtitle: l10n.loggingModeRowTrackedSubtitle,
          onTap: _startTrackedSession,
        ),
      _ModeRow(
        key: _fullModeCardKey,
        iconAsset: 'assets/icons/Table.svg',
        title: l10n.loggingModeFullTitle,
        subtitle: l10n.loggingModeRowFullSubtitle,
        onTap: _startFullLogging,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_running != null) _runningBanner(l10n),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxs),
          rows[i],
        ],
        if (drills) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xxs, bottom: AppSpacing.xxs),
            child: Text(l10n.loggingModePractice.toUpperCase(),
                style: AppTypography.sectionHeader()),
          ),
          _ModeRow(
            iconAsset: 'assets/icons/GameController.svg',
            title: l10n.loggingTrainingDrills,
            subtitle: l10n.loggingModeRowDrillsSubtitle,
            badge: l10n.loggingPro,
            onTap: _openDrills,
          ),
        ],
      ],
    );
  }

  Widget _runningBanner(AppLocalizations l10n) {
    final name = runningSessionLabel(l10n, _running!);
    final text = _showSingleHandCard
        ? l10n.loggingModeRunningBanner(name)
        : l10n.loggingModeRunningBannerShort(name);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: '$text. ${l10n.trackedRunningGoTo}',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _goToRunning,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
              border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(width: AppSpacing.xxs),
                SvgPicture.asset(
                  'assets/icons/CaretRight.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                      AppColors.accentPrimary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One compact, full-width mode row: icon, title, one subtitle line, chevron.
/// Press feedback: a slight scale, accent border and a haptic tick.
class _ModeRow extends StatefulWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ModeRow({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  State<_ModeRow> createState() => _ModeRowState();
}

class _ModeRowState extends State<_ModeRow> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (mounted && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: _pressed ? AppColors.bgElevated : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
              border: Border.all(
                  color: _pressed
                      ? AppColors.accentPrimary.withValues(alpha: 0.5)
                      : AppColors.borderStrong),
            ),
            child: Row(
              children: [
                _icon(),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _texts()),
                if (widget.badge != null) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  _badge(widget.badge!),
                ],
                const SizedBox(width: AppSpacing.xxs),
                SvgPicture.asset(
                  'assets/icons/CaretRight.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textSecondary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon() => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: AppColors.bgPrimary),
        child: SvgPicture.asset(
          widget.iconAsset,
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
              AppColors.accentPrimary, BlendMode.srcIn),
        ),
      );

  Widget _texts() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.listRowLabel()
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(widget.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall(color: AppColors.textSecondary)),
        ],
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs, vertical: AppSpacing.xxxs),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
        ),
        child: Text(text,
            style: AppTypography.sectionHeader()
                .copyWith(fontWeight: FontWeight.w700)),
      );
}
