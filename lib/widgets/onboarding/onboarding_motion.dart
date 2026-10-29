import 'package:flutter/widgets.dart';

/// Shared motion helpers for the onboarding flow. Pure where possible.
class OnboardingMotion {
  const OnboardingMotion._();

  /// True when the OS asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// Staggered [Interval] for item [index] of [total] inside a 0..1 timeline.
/// Item i starts at `i * stepFraction` and lasts [durationFraction]; both
/// ends are clamped to 0..1 so the Interval is always valid.
Interval staggerInterval(
  int index,
  int total, {
  double stepFraction = 0.15,
  double durationFraction = 0.5,
  Curve curve = Curves.linear,
}) {
  final i = index.clamp(0, total > 0 ? total - 1 : 0);
  final begin = (i * stepFraction).clamp(0.0, 1.0);
  final end = (begin + durationFraction).clamp(begin, 1.0);
  return Interval(begin, end, curve: curve);
}

/// Number of characters visible after [elapsed] at [charsPerSecond].
int typewriterLength(
  Duration elapsed,
  int textLength, {
  double charsPerSecond = 35,
}) {
  if (textLength <= 0 || elapsed <= Duration.zero) return 0;
  final n = (elapsed.inMicroseconds * charsPerSecond / 1e6).floor();
  return n.clamp(0, textLength);
}
