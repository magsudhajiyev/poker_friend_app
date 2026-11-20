import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../services/daily_challenge_store.dart';
import '../services/range_read_logic.dart';
import 'playing_card_face.dart';

/// Results row for a Range Read question (a [DailySpotSummary] with
/// `rangeRead` set): the question, what the player picked, the right answer
/// with its solver frequency, and a right/wrong badge. Shared by the Daily
/// Challenge results and the replay results.
class RangeReadResultRow extends StatelessWidget {
  final int number;
  final DailySpotSummary spot;

  const RangeReadResultRow(
      {super.key, required this.number, required this.spot});

  /// Swaps the hand class inside the localized [label] for its card pair;
  /// keeps the plain text when there are no cards (old data).
  List<Widget> _handLine(RangeReadOption o, String label, TextStyle dim) {
    final at = label.indexOf(o.hand);
    if (o.cards.length != 2 || at < 0) return [Text(label, style: dim)];
    final pre = label.substring(0, at).trim();
    final post = label.substring(at + o.hand.length).trim();
    return [
      if (pre.isNotEmpty) Text(pre, style: dim),
      for (final c in o.cards) PlayingCardFace(c, width: 20),
      if (post.isNotEmpty) Text(post, style: dim),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final a = spot.rangeRead!;
    final q = a.question;
    final right = a.right;
    final color = right ? AppColors.accentPrimary : AppColors.accentDanger;
    final picked = a.chosen >= 0 && a.chosen < q.options.length
        ? q.options[a.chosen]
        : null;
    final answer = q.options.isNotEmpty && q.correctIndex < q.options.length
        ? q.options[q.correctIndex]
        : null;
    final title = q.type == RangeReadType.also
        ? l10n.rangeReadResultAlso(q.actionWord)
        : l10n.rangeReadResultNot(q.actionWord);
    final dim = AppTypography.ibm(fontSize: 12, color: AppColors.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number',
            style: AppTypography.mono(
                fontSize: 12, color: AppColors.textDisabled)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.rangeReadTitle} · $title',
                  style: AppTypography.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xxxs),
              Wrap(
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (picked != null)
                    ..._handLine(
                        picked, l10n.rangeReadYouPicked(picked.hand), dim),
                  if (!right && answer != null)
                    ..._handLine(
                        answer,
                        l10n.rangeReadAnswerIs(answer.hand,
                            (answer.freq * 100).round().toString()),
                        dim),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          ),
          child: Icon(right ? Icons.check_rounded : Icons.close_rounded,
              size: 14, color: color),
        ),
      ],
    );
  }
}
