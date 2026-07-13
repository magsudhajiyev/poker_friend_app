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
            // Progress bar — the current-step highlight slides between
            // positions when [currentStep] changes.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _AnimatedProgressBar(
                currentStep: currentStep,
                totalSteps: totalSteps,
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

/// Progress bar with a **slide highlight** — renders 6 gray track segments
/// and a single overlaid green bar positioned over the current step. When
/// [currentStep] changes the green bar animates its `left` position, so the
/// highlight appears to glide between steps rather than snapping.
class _AnimatedProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final double gap;
  final double height;

  const _AnimatedProgressBar({
    required this.currentStep,
    required this.totalSteps,
    this.gap = 8,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth =
            (constraints.maxWidth - gap * (totalSteps - 1)) / totalSteps;
        final highlightLeft = (currentStep - 1) * (segmentWidth + gap);
        return SizedBox(
          height: height,
          width: constraints.maxWidth,
          child: Stack(
            children: [
              // Gray track — all segments always visible.
              Row(
                children: [
                  for (int i = 0; i < totalSteps; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Container(
                      width: segmentWidth,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius:
                            BorderRadius.circular(height / 2),
                      ),
                    ),
                  ],
                ],
              ),
              // Green highlight — slides to the current step position.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: highlightLeft.clamp(0.0, double.infinity),
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
