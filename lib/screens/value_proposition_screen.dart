import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../services/subscription_logic.dart' show TrialOffer, TrialUnit;

/// "How Does the Free Trial Work?" explainer, shown after the user picks a plan
/// on the paywall and taps Continue, BEFORE the purchase is started. It frames
/// the trial (today free → reminder before charge → cancel anytime), explains
/// how to cancel, and the CTA starts the actual store purchase (card sheet) via
/// [onStartTrial].
///
/// Everything trial-specific ([trial], [tierName], [priceLine]) is passed in by
/// the paywall from the store product — never hardcoded, so the day count and
/// price always match what the user will actually be charged. The steps fade +
/// slide in top→bottom on open.
class ValuePropositionScreen extends StatefulWidget {
  /// The free trial for the selected plan, or null when the plan has no trial
  /// (then the screen reads as a plain "what you get" upsell, CTA = Continue).
  final TrialOffer? trial;

  /// Localized tier name, e.g. "Pro" / "Elite" / "Club". Used in the feature
  /// copy ("all Pro features").
  final String tierName;

  /// What the user pays after the trial, e.g. "$159.99/year".
  final String priceLine;

  /// Starts the real store purchase (card sheet). Called by the CTA.
  final VoidCallback onStartTrial;

  const ValuePropositionScreen({
    super.key,
    required this.trial,
    required this.tierName,
    required this.priceLine,
    required this.onStartTrial,
  });

  @override
  State<ValuePropositionScreen> createState() => _ValuePropositionScreenState();
}

class _ValuePropositionScreenState extends State<ValuePropositionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isApple => Platform.isIOS || Platform.isMacOS;
  String get _storeName => _isApple ? 'App Store' : 'Google Play';

  /// Total trial length in days (a month is treated as 30 for the timeline, to
  /// match the real store "1 month" = 30-day trial).
  int get _trialDays {
    final t = widget.trial;
    if (t == null) return 0;
    return t.unit == TrialUnit.day ? t.count : t.count * 30;
  }

  bool get _hasTrial => widget.trial != null && _trialDays > 0;

  /// Final-day label — the day the card is charged, e.g. "Day 7" / "Day 30".
  String _lastDayLabel(AppLocalizations l10n) =>
      _trialDays > 1 ? l10n.vpStepLastTitle(_trialDays) : l10n.vpStepLastTitleFallback;

  /// Whether the trial is long enough to show a middle ("Day 2-N") step.
  bool get _hasMiddle => _trialDays > 2;

  String _cancelSteps(AppLocalizations l10n) =>
      _isApple ? l10n.vpCancelStepsApple : l10n.vpCancelStepsGoogle;

  String _durationLabel(AppLocalizations l10n) {
    final t = widget.trial!;
    return t.unit == TrialUnit.month
        ? l10n.paywallTrialMonths(t.count)
        : l10n.paywallTrialDays(t.count);
  }

  List<_TimelineStep> _buildSteps(AppLocalizations l10n) => [
        _TimelineStep(
          icon: Icons.lock_open_rounded,
          title: l10n.vpStepTodayTitle,
          body: l10n.vpStepTodayBody(widget.tierName),
        ),
        if (_hasMiddle)
          _TimelineStep(
            icon: Icons.notifications_rounded,
            title: l10n.vpStepMiddleTitle(_trialDays - 1),
            body: l10n.vpStepMiddleBody(widget.tierName),
          ),
        _TimelineStep(
          icon: Icons.star_rounded,
          title: _lastDayLabel(l10n),
          body: l10n.vpStepLastBody,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A fade + slide-up interval for the [index]-th animated block (0-based),
  /// staggered so blocks arrive one after another top→bottom. Each block's
  /// window is a fixed fraction with overlap, and every window finishes before
  /// the controller ends so nothing is left invisible.
  Widget _staggered(int index, int total, Widget child) {
    // Evenly spaced starts within [0, 0.7], each block taking ~0.3 of the
    // timeline to complete — more separation between arrivals (slower, one at a
    // time). The last block starts by 0.7 and finishes at 1.0, so every block
    // animates within the controller's (longer) duration.
    final span = total <= 1 ? 0.0 : 0.7 / (total - 1);
    final start = (index * span).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _controller,
      // easeInOutCubic reads smoother than easeOut — gentle in and out.
      curve: Interval(start, end, curve: Curves.easeInOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 28),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = _buildSteps(l10n);
    // Animated blocks: header, each step, cancel card. (Footer stays static.)
    final blockCount = 1 + steps.length + (_hasTrial ? 1 : 0);
    var idx = 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xxxl, AppSpacing.xl, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _staggered(idx++, blockCount, _header(l10n)),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (_hasTrial) ...[
                      // The connected capsule rail spans all steps; each step's
                      // text fades in on its own.
                      _timeline(l10n, steps, () => idx++, blockCount),
                      const SizedBox(height: AppSpacing.xxxl),
                      _staggered(idx++, blockCount, _cancelCard(l10n)),
                    ] else
                      _staggered(idx++, blockCount, _noTrialBlurb(l10n)),
                  ],
                ),
              ),
            ),
            _footer(l10n),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _header(AppLocalizations l10n) {
    return Center(
      child: Column(
        children: [
          Text(
            l10n.vpBrand,
            style: AppTypography.ibm(
              color: AppColors.accentPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _hasTrial ? l10n.vpTitle : l10n.vpTitleNoTrial(widget.tierName),
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Trial timeline ────────────────────────────────────────────────────────
  // A single solid green capsule runs behind evenly spaced icon nodes (matching
  // the reference); each step's TEXT fades/slides in on its own.

  Widget _timeline(AppLocalizations l10n, List<_TimelineStep> steps,
      int Function() nextIdx, int total) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _staggered(
            nextIdx(),
            total,
            _stepRow(steps[i], isFirst: i == 0, isLast: i == steps.length - 1),
          ),
      ],
    );
  }

  /// One timeline row: a green icon node on a connecting capsule rail + the
  /// step text. Row-per-step with IntrinsicHeight keeps the icon aligned with
  /// its title and the rail sized to the (variable-height) text — no magic
  /// numbers, no overflow.
  Widget _stepRow(_TimelineStep step,
      {required bool isFirst, required bool isLast}) {
    const nodeSize = 44.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail: connector above the node, the node, connector below.
          SizedBox(
            width: nodeSize,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 6,
                    color: isFirst
                        ? Colors.transparent
                        : AppColors.accentPrimary,
                  ),
                ),
                Container(
                  width: nodeSize,
                  height: nodeSize,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    borderRadius: BorderRadius.circular(nodeSize),
                  ),
                  child: Icon(step.icon, color: AppColors.paper, size: 24),
                ),
                Expanded(
                  child: Container(
                    width: 6,
                    color: isLast
                        ? Colors.transparent
                        : AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Step text. Top padding aligns the title with the icon node; bottom
          // padding is the gap to the next step.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  top: AppSpacing.xxs, bottom: isLast ? 0 : AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
                    style: AppTypography.ibm(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.body,
                    style: AppTypography.ibm(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cancel card ───────────────────────────────────────────────────────────

  Widget _cancelCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.vpCancelTitle,
            style: AppTypography.ibm(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _cancelSteps(l10n),
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── No-trial fallback ──────────────────────────────────────────────────────

  Widget _noTrialBlurb(AppLocalizations l10n) {
    return Text(
      l10n.vpNoTrialBlurb(widget.tierName),
      style: AppTypography.ibm(
        color: AppColors.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  // ── Footer (security badge + CTA + links) ──────────────────────────────────

  Widget _footer(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasTrial) ...[
            Icon(Icons.verified_user_rounded,
                color: AppColors.accentPrimary, size: 30),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.vpNoPayment,
              style: AppTypography.ibm(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              l10n.vpSecured(_storeName),
              style: AppTypography.ibm(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _cta(l10n),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _hasTrial
                ? l10n.vpFooterTrial(_durationLabel(l10n), widget.priceLine)
                : widget.priceLine,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              color: AppColors.textDisabled,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cta(AppLocalizations l10n) {
    return GestureDetector(
      onTap: widget.onStartTrial,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary,
          borderRadius: BorderRadius.circular(60),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPrimary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _hasTrial ? l10n.vpCtaTrial : l10n.vpCtaContinue,
            style: AppTypography.ibm(
              color: AppColors.paper,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineStep {
  final IconData icon;
  final String title;
  final String body;
  const _TimelineStep(
      {required this.icon, required this.title, required this.body});
}
