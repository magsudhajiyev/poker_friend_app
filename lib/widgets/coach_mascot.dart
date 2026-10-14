import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../models/drill_models.dart';

/// The Daily Challenge coach mascots: 3D-rendered expression stills
/// (assets/mascots/{persona}_{expression}.png, generated via Higgsfield)
/// inside a small motion rig. Motion is ONE-SHOT only — a springy bounce on
/// happy, a damped head-shake on upset — the mascot otherwise holds still
/// (constant wiggling tested poorly). The vector painter below is the
/// automatic fallback for any persona without shipped assets.
enum CoachExpression { idle, happy, ok, upset }

class CoachMascot extends StatefulWidget {
  final String personaId; // grinder | professor | nova
  final CoachExpression expression;
  final double size;

  const CoachMascot({
    super.key,
    required this.personaId,
    required this.expression,
    required this.size,
  });

  /// Verdict → face. Pure (unit-tested).
  static CoachExpression expressionFor(DrillGrade grade) => switch (grade) {
        DrillGrade.correct => CoachExpression.happy,
        DrillGrade.ok => CoachExpression.ok,
        DrillGrade.mistake => CoachExpression.upset,
      };

  @override
  State<CoachMascot> createState() => _CoachMascotState();
}

class _CoachMascotState extends State<CoachMascot>
    with SingleTickerProviderStateMixin {
  // Reaction: scale bounce (happy) or x-shake (upset), one-shot.
  late final AnimationController _reaction = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    _playReaction(widget.expression);
  }

  @override
  void didUpdateWidget(CoachMascot old) {
    super.didUpdateWidget(old);
    if (old.expression != widget.expression) {
      _playReaction(widget.expression);
    }
  }

  void _playReaction(CoachExpression expression) {
    if (expression == CoachExpression.happy ||
        expression == CoachExpression.upset) {
      _reaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reaction,
      builder: (context, _) {
        final t = _reaction.value;
        double scale = 1;
        double dx = 0;
        if (widget.expression == CoachExpression.happy) {
          // Quick bounce: up to 1.14 and back with an ease-out tail.
          scale = 1 + 0.14 * math.sin(t * math.pi) * (1 - t * 0.3);
        } else if (widget.expression == CoachExpression.upset) {
          // Damped head-shake.
          dx = widget.size * 0.06 * math.sin(t * math.pi * 4) * (1 - t);
        }
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            child: SizedBox.square(
              dimension: widget.size,
              child: Image.asset(
                'assets/mascots/${widget.personaId}_'
                '${widget.expression.name}.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, _, __) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _MascotPainter(
                    personaId: widget.personaId,
                    expression: widget.expression,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MascotPainter extends CustomPainter {
  final String personaId;
  final CoachExpression expression;

  _MascotPainter({required this.personaId, required this.expression});

  Color get _accent => switch (personaId) {
        'professor' => AppColors.accentPrimary,
        'nova' => AppColors.accentDanger,
        _ => AppColors.accentTertiary, // grinder
      };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s * 0.56); // head center, leaves hat room
    final r = s * 0.34;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.85);
    final accentLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round
      ..color = _accent;
    final accentFill = Paint()..color = _accent.withValues(alpha: 0.9);

    canvas.drawCircle(c, r, line);
    _paintAccessory(canvas, s, c, r, accentLine, accentFill);
    _paintEyesAndBrows(canvas, s, c, r, line, accentLine);
    _paintMouth(canvas, s, c, r, line);
  }

  void _paintEyesAndBrows(Canvas canvas, double s, Offset c, double r,
      Paint line, Paint accentLine) {
    final eyeDx = r * 0.42;
    final eyeY = c.dy - r * 0.12;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.9);

    for (final side in const [-1, 1]) {
      final e = Offset(c.dx + side * eyeDx, eyeY);
      if (expression == CoachExpression.happy) {
        final p = Path()
          ..moveTo(e.dx - r * 0.18, e.dy + r * 0.05)
          ..quadraticBezierTo(
              e.dx, e.dy - r * 0.18, e.dx + r * 0.18, e.dy + r * 0.05);
        canvas.drawPath(p, line);
      } else {
        canvas.drawCircle(e, r * 0.085, dot);
      }

      final browY = e.dy - r * 0.3;
      if (expression == CoachExpression.upset) {
        canvas.drawLine(
          Offset(e.dx - side * r * 0.2, browY - r * 0.02),
          Offset(e.dx + side * r * 0.16, browY - r * 0.16),
          line,
        );
      } else if (expression == CoachExpression.ok && side == 1) {
        canvas.drawLine(
          Offset(e.dx - r * 0.18, browY - r * 0.1),
          Offset(e.dx + r * 0.18, browY - r * 0.14),
          line,
        );
      }
    }
  }

  void _paintMouth(
      Canvas canvas, double s, Offset c, double r, Paint line) {
    final m = Offset(c.dx, c.dy + r * 0.42);
    switch (expression) {
      case CoachExpression.happy:
        final p = Path()
          ..moveTo(m.dx - r * 0.32, m.dy - r * 0.08)
          ..quadraticBezierTo(
              m.dx, m.dy + r * 0.28, m.dx + r * 0.32, m.dy - r * 0.08);
        canvas.drawPath(p, line);
      case CoachExpression.ok:
        canvas.drawLine(Offset(m.dx - r * 0.22, m.dy),
            Offset(m.dx + r * 0.22, m.dy), line);
      case CoachExpression.upset:
        final p = Path()
          ..moveTo(m.dx - r * 0.26, m.dy + r * 0.1)
          ..quadraticBezierTo(
              m.dx, m.dy - r * 0.18, m.dx + r * 0.26, m.dy + r * 0.1);
        canvas.drawPath(p, line);
      case CoachExpression.idle:
        final p = Path()
          ..moveTo(m.dx - r * 0.2, m.dy)
          ..quadraticBezierTo(
              m.dx, m.dy + r * 0.12, m.dx + r * 0.2, m.dy);
        canvas.drawPath(p, line);
    }
  }

  void _paintAccessory(Canvas canvas, double s, Offset c, double r,
      Paint accentLine, Paint accentFill) {
    switch (personaId) {
      case 'professor':
        final eyeDx = r * 0.42;
        final eyeY = c.dy - r * 0.12;
        for (final side in const [-1, 1]) {
          canvas.drawCircle(
              Offset(c.dx + side * eyeDx, eyeY), r * 0.3, accentLine);
        }
        canvas.drawLine(Offset(c.dx - eyeDx + r * 0.3, eyeY),
            Offset(c.dx + eyeDx - r * 0.3, eyeY), accentLine);
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(c.dx + i * r * 0.28, c.dy - r * 1.0),
            Offset(c.dx + i * r * 0.36, c.dy - r * 1.28),
            accentLine,
          );
        }
      case 'nova':
        // High ponytail swooping right + a star on the cheek.
        final tail = Path()
          ..moveTo(c.dx - r * 0.1, c.dy - r * 1.0)
          ..quadraticBezierTo(c.dx + r * 0.5, c.dy - r * 1.5,
              c.dx + r * 0.95, c.dy - r * 0.7)
          ..quadraticBezierTo(c.dx + r * 1.1, c.dy - r * 0.35,
              c.dx + r * 0.9, c.dy - r * 0.1);
        canvas.drawPath(tail, accentLine);
        final star = Path();
        final sc = Offset(c.dx - r * 0.55, c.dy + r * 0.35);
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 4 * math.pi / 5;
          final pt = Offset(sc.dx + r * 0.16 * math.cos(a),
              sc.dy + r * 0.16 * math.sin(a));
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        canvas.drawPath(star, accentFill);
      default: // grinder — cowboy hat + mustache
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy - r * 0.92),
              width: r * 2.5,
              height: r * 0.42),
          accentFill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy - r * 1.22),
                width: r * 1.1,
                height: r * 0.75),
            Radius.circular(r * 0.25),
          ),
          accentFill,
        );
        final mY = c.dy + r * 0.22;
        for (final side in const [-1, 1]) {
          final p = Path()
            ..moveTo(c.dx, mY)
            ..quadraticBezierTo(c.dx + side * r * 0.3, mY - r * 0.06,
                c.dx + side * r * 0.42, mY + r * 0.12);
          canvas.drawPath(p, accentLine);
        }
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.personaId != personaId || old.expression != expression;
}
