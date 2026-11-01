import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';

/// Result of the board dialogs when the user taps "Add later": the street
/// advance is confirmed but no card values are stored yet.
class BoardAddLater {
  const BoardAddLater();
}

/// Reminder shown while a hand runs with a deferred board. Tapping "Add
/// board" re-opens the entry for the missing streets.
class BoardAddLaterBar extends StatelessWidget {
  final VoidCallback onAddNow;

  const BoardAddLaterBar({super.key, required this.onAddNow});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxxs),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.easyLogBoardPending,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ibm(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAddNow,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Text(
                  l10n.easyLogBoardAddNow,
                  style: AppTypography.ibm(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
