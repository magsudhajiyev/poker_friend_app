import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';

/// Tools strip attached to the summary card: a labelled "BB | $" display
/// switch on the left, export + share on the right. Wraps instead of
/// overflowing on narrow screens / large text.
class HandToolsStrip extends StatelessWidget {
  final bool showBB;
  final ValueChanged<bool> onShowBBChanged;

  /// Label of the non-BB segment: the currency symbol (cash) or "Chips".
  final String amountLabel;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final bool isSharing;

  const HandToolsStrip({
    super.key,
    required this.showBB,
    required this.onShowBBChanged,
    required this.amountLabel,
    required this.onExport,
    required this.onShare,
    this.isSharing = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _Segmented(
          showBB: showBB,
          amountLabel: amountLabel,
          tooltip: l10n.handActionsToggleBB,
          onChanged: onShowBBChanged,
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _IconTool(
            tooltip: l10n.handActionsExportHand,
            onTap: onExport,
            child: const Icon(Icons.download,
                color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 8),
          _IconTool(
            tooltip: l10n.handActionsShareHand,
            onTap: onShare,
            child: isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : const Icon(Icons.ios_share,
                    color: AppColors.textPrimary, size: 20),
          ),
        ]),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  final bool showBB;
  final String amountLabel;
  final String tooltip;
  final ValueChanged<bool> onChanged;

  const _Segmented({
    required this.showBB,
    required this.amountLabel,
    required this.tooltip,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: tooltip,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _segment('BB', showBB, () => onChanged(true)),
          _segment(amountLabel, !showBB, () => onChanged(false)),
        ]),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentPrimary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: AppTypography.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color:
                  selected ? AppColors.accentPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTool extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _IconTool(
      {required this.tooltip, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: AppColors.bgPrimary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
