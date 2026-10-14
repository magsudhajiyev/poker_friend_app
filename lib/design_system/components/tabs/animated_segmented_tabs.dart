import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/typography.dart';

/// Dark segmented tab control driven by a [TabController].
///
/// Renders a `bgSurface` outer pill with a sliding `bgElevated` active pill
/// on top. The pill position is bound to `controller.animation!.value`, so
/// dragging the underlying [TabBarView] slides the pill continuously with
/// the finger.
///
/// Motion polish:
/// - Pill position is LINEAR in the controller value: drags track the
///   finger 1:1 and `animateTo` already eases. (An extra curve here breaks
///   3+ tabs — the intermediate stops land between slots.)
/// - Subtle drop shadow on the active pill so it lifts off the surface as
///   it moves.
/// - Labels lerp `textSecondary → textPrimary` and scale 0.96 → 1.00 based
///   on their per-tab activeness fraction (both animate at once, so the
///   outgoing label shrinks/greys as the incoming grows/whitens).
class AnimatedSegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const AnimatedSegmentedTabs({
    super.key,
    required this.controller,
    required this.labels,
  }) : assert(labels.length >= 2);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final t = controller.animation!.value
            .clamp(0.0, (labels.length - 1).toDouble());
        final pillT = t / (labels.length - 1);
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: LayoutBuilder(
            builder: (context, cons) {
              final pillW = cons.maxWidth / labels.length;
              final travel = cons.maxWidth - pillW;
              return SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: pillT * travel,
                      width: pillW,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(
                              AppDecorations.radiusFull),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(labels.length, (i) {
                        final distance = (t - i).abs();
                        final activeness =
                            (1 - distance).clamp(0.0, 1.0).toDouble();
                        return Expanded(
                          child: _SegmentLabel(
                            label: labels[i],
                            activeness: activeness,
                            onTap: () => controller.animateTo(i),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final String label;
  final double activeness;
  final VoidCallback onTap;

  const _SegmentLabel({
    required this.label,
    required this.activeness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Transform.scale(
          scale: 0.96 + 0.04 * activeness,
          child: Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Color.lerp(
                AppColors.textSecondary,
                AppColors.textPrimary,
                activeness,
              ),
              height: 24 / 15,
            ),
          ),
        ),
      ),
    );
  }
}
