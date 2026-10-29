import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';

/// Onboarding illustration: 7 day dots fill, a flame pops in, counter ticks.
class StreakFlameStrip extends StatefulWidget {
  final String header;
  final String caption;
  final List<String> weekdayLetters;
  final String semanticsLabel;
  final Duration startDelay;

  /// When false the widget draws no card chrome (a host provides it).

  const StreakFlameStrip({
    super.key,
    required this.header,
    required this.caption,
    required this.weekdayLetters,
    required this.semanticsLabel,
    this.startDelay = const Duration(milliseconds: 1100),
  });

  @override
  State<StreakFlameStrip> createState() => _StreakFlameStripState();
}

class _StreakFlameStripState extends State<StreakFlameStrip>
    with TickerProviderStateMixin {
  static const int _days = 7;
  static const int _stepMs = 90;
  static const int _dotMs = 220;
  static const int _flameMs = 600;

  late final AnimationController _fill;
  late final AnimationController _flame;
  late final AnimationController _flicker;
  bool _started = false;
  bool _reduced = false;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _stepMs * (_days - 1) + _dotMs),
    );
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _flameMs),
    );
    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fill.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _flame.forward();
    });
    _flame.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_reduced) {
        _flicker.repeat(reverse: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) {
      _fill.value = 1;
      _flame.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _startTimer = Timer(widget.startDelay, () {
        if (mounted && !_reduced) _fill.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _fill.dispose();
    _flame.dispose();
    _flicker.dispose();
    super.dispose();
  }

  double _dotProgress(int i) {
    final totalMs = _stepMs * (_days - 1) + _dotMs;
    final t = _fill.value * totalMs - i * _stepMs;
    return Curves.easeOut.transform((t / _dotMs).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: AppDecorations.borderThin,
            ),
            borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          ),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.header.toUpperCase(), style: AppTypography.sectionHeader()),
        const SizedBox(height: AppSpacing.sm),
        AnimatedBuilder(
          animation: Listenable.merge([_fill, _flame]),
          builder: (_, __) => _row(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.caption,
            style: AppTypography.bodySmall(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _row(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _days; i++) Expanded(child: _dot(i)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _flameWithCounter(),
      ],
    );
  }

  Widget _dot(int i) {
    final p = _dotProgress(i);
    final last = i == _days - 1;
    // One-shot pulse on the last dot as it completes.
    final pulse = last ? 1 + 0.25 * _bump(p) : 1.0;
    final letter =
        i < widget.weekdayLetters.length ? widget.weekdayLetters[i] : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: pulse,
          child: Container(
            width: AppSpacing.lg,
            height: AppSpacing.lg,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(Colors.white.withValues(alpha: 0.10),
                  AppColors.accentPrimary, p),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxxs),
        Text(letter,
            style: AppTypography.bodySmall(color: AppColors.textSecondary)),
      ],
    );
  }

  double _bump(double p) => p <= 0 || p >= 1 ? 0 : (1 - (2 * p - 1).abs());

  Widget _flameWithCounter() {
    final f = Curves.elasticOut.transform(_flame.value);
    final count = (_fill.value * _days).floor().clamp(0, _days);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: AppSpacing.xxxl,
          height: AppSpacing.xxxl,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _flicker,
              builder: (_, __) {
                final live = !_reduced && _flame.isCompleted;
                // easeInOut 0..1 (reverse-repeating) mapped to -1..1.
                final w = live
                    ? 2 * Curves.easeInOut.transform(_flicker.value) - 1
                    : 0.0;
                final glow = live ? 0.5 + 0.5 * w : 0.0;
                return Transform(
                  key: const Key('streakFlameTransform'),
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..rotateZ(w * 4 * math.pi / 180)
                    ..scale(f * (1 + 0.08 * w)),
                  child: CustomPaint(painter: _FlamePainter(glow)),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xxxs),
        Text('$count',
            style: AppTypography.mono(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _FlamePainter extends CustomPainter {
  final double glow;
  const _FlamePainter([this.glow = 0]);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Path drop(double k) {
      final cx = w / 2, top = h * (1 - k), bw = w * 0.5 * k;
      return Path()
        ..moveTo(cx, top)
        ..cubicTo(cx + bw * 0.2, top + (h - top) * 0.3, cx + bw,
            top + (h - top) * 0.55, cx + bw * 0.8, top + (h - top) * 0.8)
        ..quadraticBezierTo(cx + bw * 0.5, h, cx, h)
        ..quadraticBezierTo(
            cx - bw * 0.5, h, cx - bw * 0.8, top + (h - top) * 0.8)
        ..cubicTo(cx - bw, top + (h - top) * 0.55, cx - bw * 0.2,
            top + (h - top) * 0.3, cx, top)
        ..close();
    }

    canvas.drawPath(drop(0.95), Paint()..color = AppColors.accentTertiary);
    canvas.drawPath(
        drop(0.55),
        Paint()
          ..color =
              Color.lerp(AppColors.warningAmber, Colors.white, 0.35 * glow)!
                  .withValues(alpha: 0.75 + 0.25 * glow));
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) => old.glow != glow;
}
