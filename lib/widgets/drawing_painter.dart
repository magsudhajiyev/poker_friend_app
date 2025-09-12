import 'package:flutter/material.dart';

class DrawingPainter extends CustomPainter {
  final List<Offset> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (i < points.length - 1) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}