import 'package:flutter/material.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/lists/stat_list_row.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import 'leak_example_row.dart';
import 'leak_format.dart';

/// Everything a [LeakCard] can ask its host to do. Navigation, analytics and
/// persistence stay in the screen; the card only reports intent.
class LeakCardActions {
  final ValueChanged<bool>? onToggle;
  final VoidCallback onShowBandInfo;
  final VoidCallback? onSetFocus;
  final VoidCallback? onClearFocus;
  final void Function(String ref, Map<String, dynamic> hand)? onOpenHand;
  final void Function(List<Map<String, dynamic>> hands)? onReviewAll;
  final VoidCallback? onPractice;
  final VoidCallback? onSeeHands;

  const LeakCardActions({
    required this.onShowBandInfo,
    this.onToggle,
    this.onSetFocus,
    this.onClearFocus,
    this.onOpenHand,
    this.onReviewAll,
    this.onPractice,
    this.onSeeHands,
  });
}

/// Expanded coaching content of a leak: labelled blocks (what we saw, what
/// it costs, the fix, by position, your hands) and at most two buttons.
class LeakDetail extends StatefulWidget {
  final LeakFinding finding;
  final Map<String, Map<String, dynamic>> handsByRef;
  final LeakCardActions actions;

  /// Examples shown before "Show more".
  static const collapsedExamples = 3;

  const LeakDetail({
    super.key,
    required this.finding,
    required this.handsByRef,
    required this.actions,
  });

  @override
  State<LeakDetail> createState() => _LeakDetailState();
}

class _LeakDetailState extends State<LeakDetail> {
  bool _showAll = false;

  LeakFinding get _f => widget.finding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const gap = SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        gap,
        _Block(label: l10n.leakBlockSaw, child: _body(_f.meaning)),
        gap,
        _Block(label: l10n.leakBlockCost, child: _body(_f.cost)),
        gap,
        _Block(label: l10n.leakBlockFix, child: _fix()),
        if (_f.slices.isNotEmpty) ...[
          gap,
          _Block(label: l10n.leakBlockByPosition, child: _slices(l10n)),
        ],
        if (_f.examples.isNotEmpty) ...[gap, _hands(l10n)],
        ..._buttons(l10n),
      ],
    );
  }

  Widget _body(String text) =>
      Text(text, style: AppTypography.bodyMd(color: AppColors.textPrimary));

  Widget _fix() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.tintBg(AppColors.accentPrimary),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: _body(_f.fix),
    );
  }

  Widget _slices(AppLocalizations l10n) {
    return Column(
      children: [
        for (final s in _f.slices)
          Semantics(
            excludeSemantics: true,
            label: '${s.label} ${leakPct(s.value)}, n=${s.sampleCount}'
                '${s.flagged ? ', ${l10n.leakSliceFlagged}' : ''}',
            child: StatListRow(
              label: '${s.flagged ? '⚠ ' : ''}${s.label}',
              value: '${leakPct(s.value)} · n=${s.sampleCount}',
              labelStyle: AppTypography.bodyMd(color: AppColors.textPrimary),
              valueStyle: AppTypography.dataMonoSm(
                  color: s.flagged
                      ? AppColors.accentDanger
                      : AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> get _reviewable => [
        for (final ex in _f.examples)
          if (widget.handsByRef[ex.ref] != null) widget.handsByRef[ex.ref]!,
      ];

  Widget _hands(AppLocalizations l10n) {
    final all = _f.examples;
    final shown = _showAll
        ? all
        : all.take(LeakDetail.collapsedExamples).toList();
    final hidden = all.length - shown.length;
    final canReview = _reviewable.length >= 2 && widget.actions.onReviewAll != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, not Row: at large text "Review all" drops under the label.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.leakBlockHands(all.length).toUpperCase(),
              style: AppTypography.sectionHeader(color: AppColors.textSecondary),
            ),
            if (canReview)
              TextButton.icon(
                onPressed: () => widget.actions.onReviewAll!(_reviewable),
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentSecondary,
                  minimumSize: const Size(0, AppSizes.minTapTarget),
                ),
                icon: const Icon(Icons.chevron_right, size: AppIconSize.md),
                label: Text(l10n.leakReviewAll,
                    style: AppTypography.bodySmMedium(
                        color: AppColors.accentSecondary)),
              ),
          ],
        ),
        for (final ex in shown) _exampleRow(ex),
        if (hidden > 0 || _showAll && all.length > LeakDetail.collapsedExamples)
          _moreToggle(l10n, hidden),
      ],
    );
  }

  Widget _exampleRow(LeakExample ex) {
    final hand = widget.handsByRef[ex.ref];
    return LeakExampleRow(
      example: ex,
      available: hand != null,
      onTap: hand == null || widget.actions.onOpenHand == null
          ? null
          : () => widget.actions.onOpenHand!(ex.ref, hand),
    );
  }

  Widget _moreToggle(AppLocalizations l10n, int hidden) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => setState(() => _showAll = !_showAll),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSecondary,
          minimumSize: const Size(0, AppSizes.minTapTarget),
        ),
        child: Text(
          _showAll ? l10n.leakShowLess : l10n.leakShowMoreCount(hidden),
          style: AppTypography.bodySmMedium(color: AppColors.accentSecondary),
        ),
      ),
    );
  }

  List<Widget> _buttons(AppLocalizations l10n) {
    final a = widget.actions;
    final practice = a.onPractice;
    final see = a.onSeeHands;
    if (practice == null && see == null) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      if (practice != null)
        _Cta(
          label: l10n.leakPractice,
          variant: AppButtonVariant.primaryLarge,
          icon: Icons.fitness_center,
          iconColor: AppColors.textInverse,
          onTap: practice,
        ),
      if (practice != null && see != null)
        const SizedBox(height: AppSpacing.xxs),
      if (see != null)
        _Cta(
          label: l10n.leakSeeHands,
          // Without a practice button this is the single call to action.
          variant: practice == null
              ? AppButtonVariant.primaryLarge
              : AppButtonVariant.secondaryLarge,
          icon: Icons.grid_on,
          iconColor:
              practice == null ? AppColors.textInverse : AppColors.textPrimary,
          onTap: see,
        ),
    ];
  }
}

/// Full-width [AppButton] with button semantics.
class _Cta extends StatelessWidget {
  final String label;
  final AppButtonVariant variant;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _Cta({
    required this.label,
    required this.variant,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AppButton(
        label: label,
        variant: variant,
        fullWidth: true,
        onTap: onTap,
        leadingIcon: Icon(icon, size: AppIconSize.sm, color: iconColor),
      ),
    );
  }
}

/// 12px uppercase label over its content.
class _Block extends StatelessWidget {
  final String label;
  final Widget child;
  const _Block({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(label.toUpperCase(),
              style:
                  AppTypography.sectionHeader(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: AppSpacing.xxs),
        child,
      ],
    );
  }
}
