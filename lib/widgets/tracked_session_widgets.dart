import 'package:flutter/material.dart';

import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';

/// "N hands" pill on the Session History row of a tracked session (D22).
class TrackedHandsBadge extends StatelessWidget {
  final int count;
  const TrackedHandsBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tracked-hands-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
      ),
      child: Text(
        AppLocalizations.of(context).trackedHandsBadge(count),
        style: AppTypography.ibm(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.accentPrimary,
          height: 14 / 11,
        ),
      ),
    );
  }
}

/// D24: discarding a session with logged hands says how many go with it.
class TrackedDiscardDialog {
  TrackedDiscardDialog._();

  /// The dialog text: the base message, plus the hand count when [handCount]
  /// is above zero.
  static String message(AppLocalizations l10n, int handCount) =>
      handCount > 0
          ? '${l10n.trackedDiscardMessage}\n${l10n.trackedDiscardHands(handCount)}'
          : l10n.trackedDiscardMessage;

  static Future<bool> confirm(BuildContext context, int handCount) {
    final l10n = AppLocalizations.of(context);
    return ConfirmDialog.confirm(
      context,
      title: l10n.trackedDiscardTitle,
      message: message(l10n, handCount),
      confirmLabel: l10n.trackedDiscardConfirm,
    );
  }
}
