import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/villain_tracker.dart';

/// One-line payoff under the top bar: how a seat played tonight.
/// Renders nothing when [line] is null (sample below the minimum).
class VillainLineStrip extends StatelessWidget {
  final VillainLine? line;

  /// Display label for the seat (position or `P{seat}`), resolved by the host.
  final String seatLabel;

  const VillainLineStrip({super.key, required this.line, required this.seatLabel});

  /// Localised text for [line]; exposed for tests and toasts.
  static String textFor(AppLocalizations l10n, VillainLine line, String seat) =>
      switch (line.kind) {
        VillainLineKind.foldedToCbet =>
          l10n.easyLogVillainFoldedToCbet(seat, line.count, line.total),
        VillainLineKind.foldedTo3Bet =>
          l10n.easyLogVillainFoldedTo3Bet(seat, line.count, line.total),
        VillainLineKind.threeBets =>
          l10n.easyLogVillain3Bets(seat, line.count, line.total),
        VillainLineKind.vpip =>
          l10n.easyLogVillainVpip(seat, line.count, line.total),
      };

  @override
  Widget build(BuildContext context) {
    final l = line;
    if (l == null || l.total < kPayoffMinSample) return const SizedBox.shrink();
    final text = textFor(AppLocalizations.of(context), l, seatLabel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      color: AppColors.surfaceVariant1,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTypography.ibm(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.accentSecondary,
        ),
      ),
    );
  }
}
