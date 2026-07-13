import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';

/// Shared scaffold for onboarding steps.
///
/// Layout matches the Figma spec:
/// - Solid `bgPrimary` background
/// - 6-segment progress bar at top — **only the current segment** is
///   highlighted `accentPrimary`, all others render `borderStrong`
/// - No top-of-screen back button (removed per Figma). Back navigation is
///   an outlined pill BELOW the Continue button.
/// - Continue button uses the canonical dark filled pill (see
///   [_ContinueButton]).
///
/// Each step supplies its own [child] for the middle content plus its
/// step number so the progress bar reflects position in the flow.
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
            // Progress bar — only the CURRENT segment is highlighted.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                children: [
                  for (int i = 0; i < totalSteps; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == currentStep - 1
                              ? AppColors.accentPrimary
                              : AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

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
