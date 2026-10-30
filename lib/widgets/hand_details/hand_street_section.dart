import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../playing_card_face.dart';
import 'hand_action_row.dart';
import 'hand_view_data.dart';

/// A street: header (name, board cards, labelled pot) + vertical action list.
/// Run-out strips have a header only.
class HandStreetSection extends StatelessWidget {
  final StreetBlock block;
  final HandViewData data;

  const HandStreetSection({super.key, required this.block, required this.data});

  static String streetName(AppLocalizations l10n, StreetKind kind) {
    switch (kind) {
      case StreetKind.preflop:
        return l10n.handActionsStreetPreflop;
      case StreetKind.flop:
        return l10n.handActionsStreetFlop;
      case StreetKind.turn:
        return l10n.handActionsStreetTurn;
      case StreetKind.river:
        return l10n.handActionsStreetRiver;
      case StreetKind.runout:
        return l10n.handActionsStreetRunout;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final street = block.kind == StreetKind.runout
        ? 'runout'
        : block.kind.name;
    final pot = data.formatter.streetPot(block.pot);
    final cardWidth = PlayingCardFace.responsiveWidth(context,
        fraction: 0.075, min: 26, max: 36);
    final hasBody = block.actions.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white.withValues(alpha: 0.05),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          streetName(l10n, block.kind),
                          style: AppTypography.ibm(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ),
                      if (block.cards.isNotEmpty)
                        Wrap(spacing: 4, runSpacing: 4, children: [
                          for (final c in block.cards)
                            PlayingCardFace(c, width: cardWidth),
                        ]),
                    ],
                  ),
                ),
                if (pot != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 0,
                    child: _PotValue(label: l10n.handActionsPot, value: pot),
                  ),
                ],
              ],
            ),
          ),
          if (hasBody)
            for (final a in block.actions)
              HandActionRow(action: a, data: data, street: street),
        ],
      ),
    );
  }
}

/// Labelled street pot: small caption above a bold mono value.
class _PotValue extends StatelessWidget {
  final String label;
  final String value;

  const _PotValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                textAlign: TextAlign.right, style: AppTypography.caption()),
            Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.dataMono(
                      color: AppColors.accentPrimary, fontSize: 18)
                  .copyWith(height: 24 / 18),
            ),
          ],
        ),
      ),
    );
  }
}
