import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/poker_positions.dart';
import 'hand_amount_formatter.dart';
import 'hand_view_data.dart';

/// One player action as a list row: position badge, player, coloured action
/// chip, amount (mono) and the player's stack (secondary).
///
/// Uses a two-column layout normally and a stacked layout when the text is
/// scaled up or the row is narrow, so it never overflows.
class HandActionRow extends StatelessWidget {
  final Map<String, dynamic> action;
  final HandViewData data;
  final String street;

  const HandActionRow({
    super.key,
    required this.action,
    required this.data,
    required this.street,
  });

  static Color colorFor(String type, {bool allIn = false}) {
    if (allIn) return AppColors.accentDanger;
    switch (type.toLowerCase()) {
      case 'fold':
        return AppColors.textSecondary;
      case 'call':
      case 'check':
        return AppColors.accentPrimary;
      case 'raise':
      case 'bet':
        return AppColors.accentTertiary;
      case 'all in':
      case 'allin':
      case 'all-in':
        return AppColors.accentDanger;
      default:
        return AppColors.textSecondary;
    }
  }

  static String labelFor(AppLocalizations l10n, String type, bool allIn) {
    if (allIn) return l10n.handActionsActionAllIn;
    switch (type.toLowerCase()) {
      case 'fold':
        return l10n.handActionsActionFold;
      case 'check':
        return l10n.handActionsActionCheck;
      case 'call':
        return l10n.handActionsActionCall;
      case 'bet':
        return l10n.handActionsActionBet;
      case 'raise':
        return l10n.handActionsActionRaise;
      case 'all in':
      case 'allin':
      case 'all-in':
        return l10n.handActionsActionAllIn;
      default:
        return type.isEmpty ? type : type[0].toUpperCase() + type.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seat = (action['player'] ?? action['playerSeat']) as int? ?? 1;
    final type = action['action'] as String? ?? 'Unknown';
    final allIn = HandViewData.isAllInAction(action);
    final isHero = data.heroSeat != null && seat == data.heroSeat;
    final isWinner = data.hand['winnerId'] != null && seat == data.hand['winnerId'];
    final position = action['playerPosition'] as String? ??
        PokerPositions.getPositionName(seat, data.buttonPosition, data.playerCount);
    final name = isHero
        ? l10n.handActionsYou
        : (data.playerNames[seat.toString()] ??
            action['playerName'] as String? ??
            l10n.handActionsPlayerSeat(seat));

    final color = colorFor(type, allIn: allIn);
    final label = labelFor(l10n, type, allIn);
    final fmt = data.formatter;
    final style = HandAmountFormatter.amountStyle(
        action: allIn ? 'all-in' : type, street: street, amount: action['amount']);
    final amountText = style == AmountStyle.none
        ? null
        : (style == AmountStyle.raiseTo
            ? l10n.handActionsToAmount(fmt.amount(action['amount']))
            : fmt.amount(action['amount']));
    final stackText = fmt.stack(action['playerStack'] ?? action['stack']);

    final badge = _PositionBadge(position, highlighted: isHero);
    final nameText = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWinner) ...[
          const Icon(Icons.emoji_events,
              color: AppColors.accentTertiary, size: 16),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: isHero ? FontWeight.w600 : FontWeight.w500,
              color: isHero ? AppColors.accentPrimary : AppColors.textPrimary,
              height: 20 / 15,
            ),
          ),
        ),
      ],
    );
    final stack = Text.rich(
      TextSpan(children: [
        TextSpan(
            text: '${l10n.handActionsStack.toLowerCase()} ',
            style: AppTypography.caption()),
        TextSpan(
            text: stackText,
            style: AppTypography.dataMono(
                fontSize: 14, color: AppColors.textSecondary)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final chip = _ActionChip(label: label, color: color);
    final amount = amountText == null
        ? null
        : Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.dataMono(),
          );

    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return Semantics(
      container: true,
      label: [
        if (isHero) l10n.handActionsYou else name,
        position,
        label,
        if (amountText != null) amountText,
      ].join(', '),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isHero
              ? AppColors.accentPrimary.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: AppColors.separatorDark),
          ),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final stacked = scale > 1.3 || c.maxWidth < 300;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  badge,
                  const SizedBox(width: 8),
                  Expanded(child: nameText),
                ]),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [chip, if (amount != null) amount, stack],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              badge,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [nameText, const SizedBox(height: 2), stack],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    chip,
                    if (amount != null) ...[const SizedBox(height: 4), amount],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _PositionBadge(this.text, {required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: AppTypography.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: highlighted ? AppColors.accentPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ActionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.ibm(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          height: 20 / 14,
        ),
      ),
    );
  }
}
