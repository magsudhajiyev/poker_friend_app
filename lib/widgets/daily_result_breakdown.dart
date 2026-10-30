import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../services/daily_challenge_store.dart';
import '../services/daily_scoring.dart';
import 'playing_card_face.dart';

/// The per-hand, street-by-street results breakdown for a Daily Challenge day.
///
/// Extracted from the Daily Challenge screen so the normal results view and the
/// replay results view render IDENTICALLY (one source of truth): authored days
/// get a collapsible section per hand (hero's real card faces, position,
/// verdict dots, accuracy %, chevron) whose rows show the street + board faces
/// + "faced → you did · coach" line; RNG days render as simple one-line rows.
class DailyResultBreakdown extends StatefulWidget {
  final DailyChallengeResult result;

  const DailyResultBreakdown({super.key, required this.result});

  @override
  State<DailyResultBreakdown> createState() => _DailyResultBreakdownState();
}

class _DailyResultBreakdownState extends State<DailyResultBreakdown> {
  static const _gold = AppColors.accentTertiary;
  static const _red = AppColors.accentDanger;

  /// Which authored hands are expanded (collapsed by default).
  final Set<int> _openHands = {};

  @override
  Widget build(BuildContext context) {
    final spots = widget.result.spots;
    // RNG day: every spot is its own one-decision "hand" → a flat list.
    final isRng = spots.every((s) => s.street.isEmpty);
    if (isRng) {
      return Column(
        children: [
          for (var i = 0; i < spots.length; i++) ...[
            if (i > 0)
              Divider(height: 16, color: Colors.white.withValues(alpha: 0.06)),
            _spotRow(i + 1, spots[i]),
          ],
        ],
      );
    }
    final accs = widget.result.handAccuracies;
    final byHand = <int, List<DailySpotSummary>>{};
    for (final s in spots) {
      (byHand[s.hand] ??= []).add(s);
    }
    final handIdx = byHand.keys.toList()..sort();
    return Column(
      children: [
        for (var k = 0; k < handIdx.length; k++) ...[
          if (k > 0)
            Divider(height: 12, color: Colors.white.withValues(alpha: 0.10)),
          _handSection(handIdx[k], byHand[handIdx[k]]!,
              handIdx[k] < accs.length ? accs[handIdx[k]] : 0),
        ],
      ],
    );
  }

  Widget _handSection(int hand, List<DailySpotSummary> rows, double accuracy) {
    final open = _openHands.contains(hand);
    final first = rows.first;
    final pct = (accuracy * 1000).round() / 10;
    final color =
        pct >= 80 ? AppColors.accentPrimary : (pct >= 50 ? _gold : _red);
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(
                () => open ? _openHands.remove(hand) : _openHands.add(hand));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Text(AppLocalizations.of(context).authoredHandLabel(hand + 1),
                    style: AppTypography.ibm(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.accentTertiary)),
                const SizedBox(width: AppSpacing.xs),
                if (_cardList(first.handClass).isNotEmpty)
                  _miniCards(_cardList(first.handClass))
                else
                  Text(first.handClass,
                      style: AppTypography.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                const SizedBox(width: AppSpacing.xxs),
                Text(first.position,
                    style: AppTypography.mono(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final r in rows)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (r.verdict) {
                              'c' => AppColors.accentPrimary,
                              'o' => _gold,
                              _ => _red,
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Text('${DailyScoring.formatPct(pct)}%',
                    style: AppTypography.mono(
                        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(
                      top: AppSpacing.xxs, bottom: AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 14,
                              color: Colors.white.withValues(alpha: 0.06)),
                        _spotRow(i + 1, rows[i]),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Authored row, line 2: what the hero faced → what they did, plus the
  /// coach's line when it differs.
  Widget _authoredActionLine(DailySpotSummary spot) {
    final hero = spot.heroLabel.isNotEmpty ? spot.heroLabel : spot.heroAction;
    final best = spot.recommendedLabel.isNotEmpty
        ? spot.recommendedLabel
        : spot.recommendedAction;
    final l10n = AppLocalizations.of(context);
    final dim = AppTypography.ibm(fontSize: 12, color: AppColors.textSecondary);
    return Text.rich(
      TextSpan(style: dim, children: [
        if (spot.facing.isNotEmpty) ...[
          TextSpan(
              text: spot.facing,
              style: dim.copyWith(color: AppColors.textPrimary)),
          const TextSpan(text: '  →  '),
        ],
        TextSpan(text: l10n.authoredYouAction(hero)),
        if (spot.verdict != 'c')
          TextSpan(text: ' · ${l10n.authoredCoachAction(best)}'),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _spotRow(int n, DailySpotSummary spot) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (spot.verdict) {
      'c' => (AppColors.accentPrimary, l10n.dailyChallengeVerdictBest),
      'o' => (_gold, l10n.dailyChallengeVerdictGood),
      _ => (_red, l10n.dailyChallengeVerdictLeak),
    };
    final number = Text('$n',
        style: AppTypography.mono(fontSize: 12, color: AppColors.textDisabled));
    final action = Text(
      spot.verdict == 'c'
          ? l10n.authoredYouAction(spot.heroAction)
          : '${l10n.authoredYouAction(spot.heroAction)} · '
              '${l10n.authoredCoachAction(spot.recommendedAction)}',
      overflow: TextOverflow.ellipsis,
      style: AppTypography.ibm(fontSize: 12, color: AppColors.textSecondary),
    );
    final badge = Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
      ),
      child: Text(label,
          style: AppTypography.ibm(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color)),
    );
    final labelStyle = AppTypography.mono(
        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

    // RNG spot: one line — holding, action, verdict.
    if (spot.street.isEmpty) {
      return Row(
        children: [
          number,
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 64,
            child:
                Text('${spot.handClass} ${spot.position}', style: labelStyle),
          ),
          Expanded(child: action),
          badge,
        ],
      );
    }

    // Authored decision: street + the board it was played on (card faces),
    // then the action line with the verdict.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        number,
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(spot.street, style: labelStyle),
                  if (spot.board.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(child: _miniCards(spot.board)),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxxs),
              _authoredActionLine(spot),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        badge,
      ],
    );
  }

  /// '9♠ 9♥' → ['9♠', '9♥']; '' when the text has no suit glyphs.
  static List<String> _cardList(String text) {
    final cards = text.split(' ').where((c) => c.isNotEmpty).toList();
    const suits = {'♠', '♥', '♦', '♣'};
    return cards.isNotEmpty &&
            cards.every((c) => c.length >= 2 && suits.contains(c[c.length - 1]))
        ? cards
        : const [];
  }

  /// Small card faces (white, rank over suit, red hearts/diamonds).
  Widget _miniCards(List<String> cards) {
    final w = (MediaQuery.sizeOf(context).width * 0.052).clamp(18.0, 24.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in cards)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: PlayingCardFace(c,
                width: w, rankSize: 11, suitSize: 10, redColor: _red),
          ),
      ],
    );
  }
}
