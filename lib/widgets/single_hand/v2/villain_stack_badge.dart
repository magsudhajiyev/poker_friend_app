import 'package:flutter/material.dart';

import '../../../design_system/constants/colors.dart';
import '../../../design_system/constants/decorations.dart';
import '../../../design_system/constants/typography.dart';

/// Small pulsing "100 BB?" tag that replaces a villain's stack line on the
/// seat plate while their stack is still the default (setup v2, D7). Purely
/// visual: the seat plate around it handles the tap. The pulse stops when the
/// system asks for reduced motion.
class VillainStackBadge extends StatefulWidget {
  final String label;
  const VillainStackBadge({super.key, required this.label});

  @override
  State<VillainStackBadge> createState() => _VillainStackBadgeState();
}

class _VillainStackBadgeState extends State<VillainStackBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _pulse.stop();
      _started = false;
    } else if (!_started) {
      _started = true;
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Opacity(
        opacity: 0.65 + 0.35 * _pulse.value,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(color: AppColors.accentPrimary, width: 1),
        ),
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.mono(
            color: AppColors.accentPrimary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
