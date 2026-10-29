import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import 'onboarding_motion.dart';

/// Speech bubble that types [text] out (~35 chars/s). Restarts when [text]
/// changes. With [animate] false, or reduced motion, shows the full text.
class TypewriterBubble extends StatefulWidget {
  final String text;
  final bool animate;

  const TypewriterBubble({super.key, required this.text, this.animate = true});

  @override
  State<TypewriterBubble> createState() => _TypewriterBubbleState();
}

class _TypewriterBubbleState extends State<TypewriterBubble>
    with SingleTickerProviderStateMixin {
  static const double _cps = 35;
  late final AnimationController _c = AnimationController(vsync: this);

  Duration get _total => Duration(
      microseconds: (widget.text.length / _cps * 1e6).round().clamp(1, 1 << 40));

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(TypewriterBubble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.animate != widget.animate) _restart();
  }

  void _restart() {
    _c.duration = _total;
    if (widget.animate) {
      _c.forward(from: 0);
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.animate && !OnboardingMotion.reduced(context)
        ? null
        : widget.text;
    return Semantics(
      container: true,
      label: widget.text,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
              size: const Size(AppSpacing.md, AppSpacing.xxs),
              painter: _TailPainter()),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: _bubbleDecoration,
            child: full != null ? _label(full, full) : _typed(),
          ),
        ],
      ),
    );
  }

  Widget _typed() => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final n = typewriterLength(_c.duration! * _c.value, widget.text.length,
              charsPerSecond: _cps);
          return _label(widget.text.substring(0, n), widget.text);
        },
      );

  // Invisible full text reserves the final height so the bubble never jumps.
  Widget _label(String shown, String full) => Stack(children: [
        Opacity(opacity: 0, child: Text(full, style: _style)),
        Text(shown, style: _style),
      ]);

  TextStyle get _style => AppTypography.bodyMedium(color: AppColors.textPrimary);
}

final BoxDecoration _bubbleDecoration = BoxDecoration(
  color: AppColors.textPrimary.withValues(alpha: 0.06),
  borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
  border: Border.all(
      color: AppColors.textPrimary.withValues(alpha: 0.10),
      width: AppDecorations.borderThin),
);

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(0, s.height)
      ..lineTo(s.width / 2, 0)
      ..lineTo(s.width, s.height);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.textPrimary.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppDecorations.borderThin);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}
