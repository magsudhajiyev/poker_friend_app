import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/components/dividers/list_separator.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../playing_card_face.dart';
import 'hand_amount_formatter.dart';
import 'hand_view_data.dart';

/// Hero summary: hero cards + full board in one row, pot, blinds, winner,
/// and any opponent hands shown at showdown.
class HandSummaryCard extends StatelessWidget {
  final HandViewData data;

  /// Optional tools strip shown under a thin separator at the card's bottom.
  final Widget? footer;

  const HandSummaryCard({super.key, required this.data, this.footer});

  /// Winner display text, or null when the hand has no recorded winner.
  /// Split pots list every winner so a side-pot winner is never hidden.
  static String? winnerText(Map<String, dynamic> hand, AppLocalizations l10n) {
    final names = hand['playerNames'];
    String nameOf(dynamic w) {
      if (names is Map) {
        final n = names[w.toString()] as String?;
        if (n != null && n.isNotEmpty) return n;
      }
      return 'Player $w';
    }

    final chopped = hand['choppedWinners'] as List<dynamic>?;
    if (hand['isChoppedPot'] == true && chopped != null && chopped.isNotEmpty) {
      if (hand['isSplitPot'] == true || chopped.length <= 2) {
        return chopped.map(nameOf).join(', ');
      }
      return l10n.handActionsPlayersCount(chopped.length);
    }
    final winnerId = hand['winnerId'];
    return winnerId != null ? nameOf(winnerId) : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hand = data.hand;
    final fmt = data.formatter;
    final pot = hand['potAmount'] ?? hand['pot'] ?? 0;
    final blinds = blindsText(hand, fmt, fmt.isCash);
    final winner = winnerText(hand, l10n);
    final cardWidth = PlayingCardFace.responsiveWidth(context);
    final board = data.board;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.hasHeroCards || board.isNotEmpty) ...[
            _cardsRow(l10n, cardWidth, board),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _Stat(
                label: l10n.handActionsPot,
                value: fmt.summaryPot(pot),
                color: AppColors.accentPrimary,
                weight: FontWeight.w700,
              ),
              _Stat(
                label: l10n.handActionsBlinds,
                value: blinds,
                color: AppColors.textPrimary,
                weight: FontWeight.w500,
              ),
              if (winner != null)
                _Stat(
                  label: l10n.handActionsWinner,
                  value: winner,
                  color: AppColors.accentTertiary,
                  weight: FontWeight.w600,
                  icon: Icons.emoji_events,
                ),
            ],
          ),
          if (data.shownHands.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.separatorDark),
            const SizedBox(height: 12),
            Text(l10n.handActionsOpponentCards, style: AppTypography.caption()),
            const SizedBox(height: 8),
            for (final s in data.shownHands) _shownRow(l10n, s, cardWidth),
          ],
          if (footer != null) ...[
            const SizedBox(height: 12),
            const ListSeparator(horizontalPadding: 0),
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }

  static String blindsText(
      Map<String, dynamic> hand, HandAmountFormatter fmt, bool isCash) {
    final sb = hand['smallBlind'] ?? 1;
    final bb = hand['bigBlind'] ?? 2;
    return isCash
        ? '${formatBlind(sb, true)}/${formatBlind(bb, true)}'
        : '${formatBlind(sb, false)}/${formatBlind(bb, false)}';
  }

  /// Blind levels are never switched to BB (they ARE the BB reference).
  static String formatBlind(dynamic v, bool isCash) =>
      HandAmountFormatter(showBB: false, bigBlind: 2, isCash: isCash)
          .amount(v is num ? v : 0);

  Widget _cardsRow(AppLocalizations l10n, double w, List<String> board) {
    // Wrap (not Row): at large text sizes the board drops below the hero
    // cards instead of overflowing.
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        if (data.hasHeroCards)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.handActionsYourCards,
                  style: AppTypography.caption(color: AppColors.accentPrimary)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (data.heroCard1 != null) PlayingCardFace(data.heroCard1!, width: w),
                if (data.heroCard1 != null && data.heroCard2 != null)
                  const SizedBox(width: 4),
                if (data.heroCard2 != null) PlayingCardFace(data.heroCard2!, width: w),
              ]),
            ],
          ),
        if (board.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.handActionsBoard, style: AppTypography.caption()),
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final c in board) PlayingCardFace(c, width: w),
              ]),
            ],
          ),
      ],
    );
  }

  Widget _shownRow(AppLocalizations l10n, ShownHand s, double w) {
    final name = s.name ?? l10n.handActionsPlayerSeat(s.seat);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          PlayingCardFace(s.card1, width: w * 0.85),
          const SizedBox(width: 4),
          PlayingCardFace(s.card2, width: w * 0.85),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final FontWeight weight;
  final IconData? icon;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.weight,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.caption()),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    fontWeight: weight,
                    color: color,
                    height: 22 / 17,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
