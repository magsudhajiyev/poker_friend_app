import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A brief animated success confirmation — a green circle pops in and
/// a check stroke draws itself, then the whole overlay fades out.
///
/// Call [SuccessCheckOverlay.show] after a modal Confirm succeeds (e.g.
/// after `Navigator.pop` returns and the underlying screen has committed
/// the write). Non-blocking — returns a Future that completes when the
/// overlay finishes and self-removes.
class SuccessCheckOverlay {
  static Future<void> show(
    BuildContext context, {
    Duration holdBefore = const Duration(milliseconds: 320),
    Duration hold = const Duration(milliseconds: 480),
  }) async {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _SuccessCheckWidget(
        holdBefore: holdBefore,
        hold: hold,
      ),
    );
    overlay.insert(entry);
    // Total lifetime: circle-in + check-draw + hold + fade-out
    await Future.delayed(holdBefore + hold + const Duration(milliseconds: 220));
    if (entry.mounted) entry.remove();
  }
}

class _SuccessCheckWidget extends StatefulWidget {
  final Duration holdBefore;
  final Duration hold;

  const _SuccessCheckWidget({
    required this.holdBefore,
    required this.hold,
  });

  @override
  State<_SuccessCheckWidget> createState() => _SuccessCheckWidgetState();
}

class _SuccessCheckWidgetState extends State<_SuccessCheckWidget>
    with TickerProviderStateMixin {
  late final AnimationController _appear;
  late final AnimationController _draw;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _run();
  }

  Future<void> _run() async {
    _appear.forward();
    await Future.delayed(widget.holdBefore);
    if (!mounted) return;
    _draw.forward();
    await Future.delayed(widget.hold);
    if (!mounted) return;
    _fade.reverse();
  }

  @override
  void dispose() {
    _appear.dispose();
    _draw.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_appear, _draw, _fade]),
        builder: (_, __) {
          final appearCurve = Curves.easeOutBack.transform(_appear.value);
          final drawCurve = Curves.easeOut.transform(_draw.value);
          return Opacity(
            opacity: _fade.value,
            child: Center(
              child: Transform.scale(
                scale: 0.5 + 0.5 * appearCurve,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.accentSecondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentSecondary.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _CheckPainter(progress: drawCurve),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = AppColors.textInverse
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Check shape: bottom-left → elbow → top-right, sized to ~55% of circle.
    final w = size.width;
    final h = size.height;
    final start = Offset(w * 0.28, h * 0.52);
    final elbow = Offset(w * 0.44, h * 0.66);
    final end = Offset(w * 0.72, h * 0.38);

    final full = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(end.dx, end.dy);

    final metric = full.computeMetrics().first;
    final extracted = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress;
}
