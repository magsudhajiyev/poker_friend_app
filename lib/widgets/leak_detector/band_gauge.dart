import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/sizes.dart';
import '../../l10n/app_localizations.dart';
import 'leak_format.dart';

/// Bullet-style band gauge: recessive track, tinted healthy-band segment,
/// status-coloured value marker with a surface ring.
///
/// Announces itself to screen readers as "<title> X%, healthy range A to B"
/// (the painted marker alone carries no semantics). Values are clamped to
/// 0..1 so a bad input can never paint outside the track.
class BandGauge extends StatelessWidget {
  final String title;
  final double value;
  final double bandLow;
  final double bandHigh;
  final Color markerColor;

  /// Thinner track + smaller marker for tiles.
  final bool compact;

  const BandGauge({
    super.key,
    required this.title,
    required this.value,
    required this.bandLow,
    required this.bandHigh,
    required this.markerColor,
    this.compact = false,
  });

  static double clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

  /// Marker centre x for [value] on a track of [width], kept fully inside it.
  static double markerX(double value, double width, double markerRadius) {
    final min = markerRadius + AppSizes.hairline;
    final max = width - markerRadius - AppSizes.hairline;
    if (max <= min) return width / 2;
    return (clamp01(value) * width).clamp(min, max);
  }

  double get _track => compact ? AppSizes.gaugeTrackSm : AppSizes.gaugeTrack;
  double get _radius => compact ? AppSizes.gaugeMarkerSm : AppSizes.gaugeMarker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final low = clamp01(bandLow);
    final high = clamp01(bandHigh);
    final target = clamp01(value);
    final center = (low + high) / 2;
    return Semantics(
      label: l10n.leakGaugeSemantics(
          title, leakPct(target), leakPct(low), leakPct(high)),
      child: ExcludeSemantics(
        // The marker sweeps from the band centre to the measured value so the
        // gauge "takes its reading" on arrival (skipped when the platform
        // asks to reduce motion).
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.of(context, AppMotion.slow),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => SizedBox(
            height: (_radius + AppSizes.gaugeMarkerRing) * 2,
            width: double.infinity,
            child: CustomPaint(
              painter: _BandGaugePainter(
                value: center + (target - center) * t,
                bandLow: low,
                bandHigh: high,
                markerColor: markerColor,
                trackHeight: _track,
                markerRadius: _radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandGaugePainter extends CustomPainter {
  final double value;
  final double bandLow;
  final double bandHigh;
  final Color markerColor;
  final double trackHeight;
  final double markerRadius;

  const _BandGaugePainter({
    required this.value,
    required this.bandLow,
    required this.bandHigh,
    required this.markerColor,
    required this.trackHeight,
    required this.markerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final top = cy - trackHeight / 2;
    final radius = Radius.circular(trackHeight / 2);

    RRect seg(double left, double width) => RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, trackHeight), radius);

    canvas.drawRRect(
        seg(0, size.width), Paint()..color = AppColors.fillSubtle);
    final lo = bandLow <= bandHigh ? bandLow : bandHigh;
    final hi = bandLow <= bandHigh ? bandHigh : bandLow;
    canvas.drawRRect(
      seg(lo * size.width, (hi - lo) * size.width),
      Paint()..color = AppColors.tintBorder(AppColors.accentPrimary),
    );

    final cx = BandGauge.markerX(value, size.width, markerRadius);
    canvas.drawCircle(
        Offset(cx, cy),
        markerRadius + AppSizes.gaugeMarkerRing,
        Paint()..color = AppColors.bgSurface);
    canvas.drawCircle(
        Offset(cx, cy), markerRadius, Paint()..color = markerColor);
  }

  @override
  bool shouldRepaint(_BandGaugePainter old) =>
      old.value != value ||
      old.bandLow != bandLow ||
      old.bandHigh != bandHigh ||
      old.markerColor != markerColor;
}
