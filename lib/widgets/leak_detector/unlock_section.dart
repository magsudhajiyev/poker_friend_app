import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/components/containers/pill_label.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import 'leak_section_header.dart';

/// Detectors that lack the sample for a verdict, framed as goals. Shows the
/// nearest one; the rest sit behind "Show N more".
class UnlockSection extends StatefulWidget {
  /// Nearest-to-unlock first.
  final List<LeakFinding> findings;
  const UnlockSection({super.key, required this.findings});

  @override
  State<UnlockSection> createState() => _UnlockSectionState();
}

class _UnlockSectionState extends State<UnlockSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = widget.findings;
    if (items.isEmpty) return const SizedBox.shrink();
    final visible = _showAll ? items : items.take(1).toList();
    final hidden = items.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeakSectionHeader(title: l10n.leakSectionUnlock),
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxs),
          UnlockTile(finding: visible[i], isNext: i == 0),
        ],
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentSecondary,
              minimumSize: const Size(0, AppSizes.minTapTarget),
            ),
            child: Text(
              _showAll ? l10n.leakShowLess : l10n.leakShowMoreCount(hidden),
              style:
                  AppTypography.bodySmMedium(color: AppColors.accentSecondary),
            ),
          ),
      ],
    );
  }
}

/// Progress-to-unlock tile: ring with the number of spots still needed,
/// title, and have/need counts.
class UnlockTile extends StatelessWidget {
  final LeakFinding finding;
  final bool isNext;
  const UnlockTile({super.key, required this.finding, this.isNext = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = finding;
    final progress = (f.sampleCount / f.minSample).clamp(0.0, 1.0);
    final remaining = (f.minSample - f.sampleCount).clamp(0, f.minSample);
    final accent =
        isNext ? AppColors.accentSecondary : AppColors.textSecondary;
    return Semantics(
      excludeSemantics: true,
      label: l10n.leakUnlockSemantics(
          f.title, f.sampleCount, f.minSample, remaining),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(
            color: isNext
                ? AppColors.tintBorder(AppColors.accentSecondary)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            _ring(context, progress, remaining, accent),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: _text(l10n, remaining)),
            const SizedBox(width: AppSpacing.xxs),
            Text(l10n.leakUnlockProgress(f.sampleCount, f.minSample),
                style:
                    AppTypography.dataMonoSm(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _ring(BuildContext context, double progress, int remaining, Color c) {
    return SizedBox(
      width: AppSizes.progressRing,
      height: AppSizes.progressRing,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: AppMotion.of(context, AppMotion.slow),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) => CustomPaint(
          painter: UnlockRingPainter(progress: p, color: c),
          child: Center(
            child: Text('$remaining', style: AppTypography.dataMonoSm()),
          ),
        ),
      ),
    );
  }

  Widget _text(AppLocalizations l10n, int remaining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(finding.title,
                style: AppTypography.bodySmMedium(
                    color: AppColors.textPrimary)),
            if (isNext)
              PillLabel(
                text: l10n.leakUnlockNext,
                backgroundColor: AppColors.accentSecondary,
                backgroundOpacity: AppColors.tintBgAlpha,
                textStyle:
                    AppTypography.caption(color: AppColors.accentSecondary),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs, vertical: AppSpacing.xxxs),
              ),
          ],
        ),
        Text(l10n.leakUnlockRemaining(remaining),
            style: AppTypography.caption()),
      ],
    );
  }
}

/// Thin circular progress ring (track + rounded arc from 12 o'clock).
class UnlockRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const UnlockRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppSizes.progressRingStroke;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.fillSubtle,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(UnlockRingPainter old) =>
      old.progress != progress || old.color != color;
}
