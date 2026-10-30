import 'package:flutter/widgets.dart';

/// Icon size scale. Use these instead of literal `size:` values.
class AppIconSize {
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
}

/// Shared component dimensions (not spacing, not type).
class AppSizes {
  /// Minimum interactive target (WCAG 2.5.5 / Material guidance).
  static const double minTapTarget = 44.0;

  /// Comfortable row height for tappable list rows.
  static const double listRowMin = 48.0;

  /// Max content width on tablets / landscape; phones are unaffected.
  static const double contentMaxWidth = 600.0;

  /// Circular progress ring (unlock / goal rings).
  static const double progressRing = 40.0;
  static const double progressRingStroke = 3.0;

  /// Square badge behind a leading icon in list rows.
  static const double iconBadge = 40.0;

  /// Small inline progress spinner.
  static const double spinner = 16.0;
  static const double spinnerStroke = 2.0;

  /// Band gauge (value vs healthy range) geometry.
  static const double gaugeTrack = 6.0;
  static const double gaugeTrackSm = 4.0;
  static const double gaugeMarker = 6.0;
  static const double gaugeMarkerSm = 4.0;
  static const double gaugeMarkerRing = 2.0;

  /// Diverging bar (profit / loss) geometry.
  static const double barHeight = 8.0;
  static const double hairline = 1.0;

  /// Border width of an emphasised (focus) card.
  static const double borderEmphasis = 1.5;
}

/// Animation durations. Always go through [AppMotion.of] so the user's
/// "remove animations" setting is respected.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 650);
  static const Duration entrance = Duration(milliseconds: 900);

  /// [d], or [Duration.zero] when the platform asks to disable animations.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
