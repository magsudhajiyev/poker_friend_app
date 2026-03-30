import 'package:flutter/material.dart';
import '../design_system/constants/typography.dart';
import 'onboarding_state.dart';

/// Thin progress bar shown at the top of screens during onboarding.
/// Only renders when [OnboardingState.isOnboardingActive] is true.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!OnboardingState.isOnboardingActive) return const SizedBox.shrink();

    final phase = OnboardingState.currentPhase;
    final total = OnboardingState.totalPhases;
    final progress = OnboardingState.progress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                widthFactor: progress,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF89F1EC),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Step ${phase + 1} of $total',
            style: AppTypography.bodySmall(
              color: Colors.white.withOpacity(0.54),
            ).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Animated version of FractionallySizedBox for smooth progress transitions.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final AlignmentGeometry alignment;
  final Widget? child;

  const AnimatedFractionallySizedBox({
    Key? key,
    required Duration duration,
    Curve curve = Curves.linear,
    required this.widthFactor,
    required this.alignment,
    this.child,
  }) : super(key: key, duration: duration, curve: curve);

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
