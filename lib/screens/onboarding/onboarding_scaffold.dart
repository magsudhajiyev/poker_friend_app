import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';

/// Shared scaffold for onboarding steps.
///
/// Layout matches the Figma spec:
/// - Solid `bgPrimary` background
/// - Space reserved at the top for the progress bar (the bar itself is
///   rendered once by [OnboardingFlow] as a persistent overlay so its
///   morphing pill animates smoothly across step changes instead of being
///   rebuilt with each PageView child).
/// - No top-of-screen back button (removed per Figma). Back navigation is
///   an outlined pill BELOW the Continue button.
/// - Continue button uses the canonical dark filled pill (see
///   [_ContinueButton]).
///
/// [currentStep] / [totalSteps] are accepted for API back-compat but are
/// unused — the persistent overlay reads its state from the flow.
class OnboardingScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  /// Back navigation. When provided, renders an outlined pill below the
  /// Continue button (not a top-of-screen circle).
  final VoidCallback? onBack;

  /// Primary CTA — usually "Continue". Disable by setting `null`.
  final VoidCallback? onContinue;
  final String continueLabel;
  final String backLabel;

  /// Optional secondary action shown BELOW everything (below Back too)
  /// for things like "Skip for now" underlined text on the nickname step.
  final Widget? secondaryAction;

  /// The step-specific content.
  final Widget child;

  /// When true, wraps [child] in a `SingleChildScrollView`. Set to false
  /// if the child manages its own scrolling.
  final bool scrollable;

  const OnboardingScaffold({
    super.key,
    required this.currentStep,
    this.totalSteps = 6,
    this.onBack,
    this.onContinue,
    this.continueLabel = 'Continue',
    this.backLabel = 'Back',
    this.secondaryAction,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: child,
    );

    return ColoredBox(
      color: AppColors.bgPrimary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Reserved space matching the progress bar's footprint (8px
            // dot height inside a 24-top-padded row + 24px bottom gap).
            // The actual bar is drawn by [OnboardingFlow] as a persistent
            // overlay so its morph animation isn't reset each page swipe.
            const SizedBox(height: 8 + 8 + 24),

            // Middle content
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(child: content)
                  : content,
            ),

            // Bottom CTAs: Continue → outlined Back → optional secondary.
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                bottomPadding > 0 ? bottomPadding + 16 : 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ContinueButton(
                    label: continueLabel,
                    onTap: onContinue,
                  ),
                  if (onBack != null) ...[
                    const SizedBox(height: 12),
                    _BackPillButton(label: backLabel, onTap: onBack!),
                  ],
                  if (secondaryAction != null) ...[
                    const SizedBox(height: 12),
                    secondaryAction!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ContinueButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Figma node 1822:13907 — bgElevated fill, borderStrong 1px border,
    // 32×16 padding, radiusFull (999), 15px SemiBold white label.
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          border: Border.all(color: AppColors.borderStrong, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 20 / 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BackPillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Outlined pill — same shape as Continue but transparent fill and a
    // `borderStrong` outline. Sits below the primary CTA on any step
    // that can go back.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppColors.borderStrong, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 20 / 15,
          ),
        ),
      ),
    );
  }
}

/// Morphing pill + dots progress indicator.
///
/// Each step is an animated pill whose width shifts between 8px (dot) and
/// 26px (active pill) on step change. Color + width transitions run in
/// parallel (380ms `easeOutCubic`), so a step advance reads as the pill
/// smoothly sliding between positions rather than snapping.
///
/// Visual states:
/// - Active   → 26px pill, `accentPrimary`, with a soft green glow.
/// - Complete → 8px dot, `accentPrimary` at 65% (muted trail behind you).
/// - Upcoming → 8px dot, white at 18% (whisper of what's ahead).
class OnboardingProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final double gap;
  final double dotSize;
  final double activeWidth;

  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.gap = 8,
    this.dotSize = 8,
    this.activeWidth = 26,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dotSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          for (int i = 0; i < totalSteps; i++) ...[
            if (i > 0) SizedBox(width: gap),
            _StepPill(
              isActive: i + 1 == currentStep,
              isDone: i + 1 < currentStep,
              dotSize: dotSize,
              activeWidth: activeWidth,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final bool isActive;
  final bool isDone;
  final double dotSize;
  final double activeWidth;

  const _StepPill({
    required this.isActive,
    required this.isDone,
    required this.dotSize,
    required this.activeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      width: isActive ? activeWidth : dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.accentPrimary
            : isDone
                ? AppColors.accentPrimary.withOpacity(0.65)
                : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(dotSize / 2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.accentPrimary.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }
}
