import 'package:flutter/material.dart';

import '../../design_system/components/headers/section_header.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import 'hand_street_section.dart';
import 'hand_view_data.dart';

/// Splits the model's reasoning into readable paragraphs: on blank/new lines,
/// else (for one long block) into groups of [sentencesPerParagraph] sentences.
List<String> splitParagraphs(String text, {int sentencesPerParagraph = 2}) {
  final byLines = text
      .split(RegExp(r'\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (byLines.length > 1 || (byLines.isNotEmpty && byLines.first.length < 280)) {
    return byLines;
  }
  if (byLines.isEmpty) return const [];
  final sentences = byLines.first
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  final out = <String>[];
  for (var i = 0; i < sentences.length; i += sentencesPerParagraph) {
    out.add(sentences
        .skip(i)
        .take(sentencesPerParagraph)
        .join(' '));
  }
  return out;
}

/// Colour token for a street grade letter.
Color gradeColor(String grade) {
  switch (grade.toUpperCase()) {
    case 'A':
      return AppColors.profitGreen;
    case 'B':
      return AppColors.accentPrimary;
    case 'C':
      return AppColors.warningAmber;
    case 'D':
      return AppColors.accentTertiary;
    case 'F':
      return AppColors.accentDanger;
    default:
      return AppColors.textSecondary;
  }
}

/// AI analysis results: reasoning, key takeaway, street grades, exploit tip.
class HandAiAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const HandAiAnalysisCard({super.key, required this.analysis});

  static const _streets = ['preflop', 'flop', 'turn', 'river'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ai = analysis['aiAnalysis'] as Map<String, dynamic>?;
    final breakdown = analysis['streetBreakdown'] as Map<String, dynamic>?;
    final tip = analysis['exploitativeTip'] as String?;
    final reasoning = ai?['reasoning'] as String?;
    final learning = ai?['learningPoint'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.handActionsAiAnalysis),
        const SizedBox(height: 12),
        if (reasoning != null && reasoning.isNotEmpty)
          _panel([
            for (final p in splitParagraphs(reasoning))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(p, style: _body),
              ),
          ]),
        if (learning != null && learning.isNotEmpty) ...[
          const SizedBox(height: 12),
          _callout(
            icon: Icons.lightbulb_outline,
            color: AppColors.accentPrimary,
            title: l10n.handActionsLearningPoint,
            text: learning,
          ),
        ],
        if (breakdown != null && breakdown.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(title: l10n.handActionsStreetByStreetBreakdown),
          const SizedBox(height: 12),
          _panel([
            for (final s in _streets.where(breakdown.containsKey))
              _gradeRow(
                l10n,
                s,
                (breakdown[s] as Map<String, dynamic>? ?? {})['analysis']
                        as String? ??
                    '',
                (breakdown[s] as Map<String, dynamic>? ?? {})['grade']
                        as String? ??
                    'C',
              ),
          ]),
        ],
        if (tip != null && tip.isNotEmpty) ...[
          const SizedBox(height: 12),
          _callout(
            icon: Icons.person_search,
            color: AppColors.accentInfo,
            title: l10n.handActionsExploitTip,
            text: tip,
          ),
        ],
      ],
    );
  }

  static TextStyle get _body => AppTypography.ibm(
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  Widget _panel(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _callout({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 4),
                Text(text, style: _body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradeRow(
      AppLocalizations l10n, String street, String text, String grade) {
    final kind = StreetKind.values.firstWhere((k) => k.name == street);
    final color = gradeColor(grade);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            ),
            child: Text(grade,
                style: AppTypography.mono(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(HandStreetSection.streetName(l10n, kind),
                    style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(text, style: _body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
