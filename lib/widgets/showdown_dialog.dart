import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/pickers/card_keyboard.dart';

class ShowdownDialog extends StatefulWidget {
  final int playerCount;
  final List<int> activePlayers;
  final ShowdownData? existingData;

  const ShowdownDialog({
    Key? key,
    required this.playerCount,
    required this.activePlayers,
    this.existingData,
  }) : super(key: key);

  @override
  _ShowdownDialogState createState() => _ShowdownDialogState();
}

class _ShowdownDialogState extends State<ShowdownDialog> {
  late ShowdownData _showdownData;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _showdownData = widget.existingData ?? ShowdownData();
    _descriptionController.text = _showdownData.handDescription ?? '';
    for (final player in widget.activePlayers) {
      _showdownData.playerCards[player] ??= HoleCards();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Set<String> get _allUsedCards {
    final used = <String>{};
    for (final cards in _showdownData.playerCards.values) {
      final c1 = cards.card1;
      final c2 = cards.card2;
      if (c1 != null && c1.length > 1) used.add(c1);
      if (c2 != null && c2.length > 1) used.add(c2);
    }
    return used;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.showdownTitle,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.showdownEnterOpponentCards,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 22 / 15,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...widget.activePlayers.map(_buildPlayerRow),
            const SizedBox(height: AppSpacing.xs),
            _buildWinnerSection(),
            const SizedBox(height: AppSpacing.md),
            _buildHandDescriptionField(),
          ],
        ),
      ),
      actions: DialogActionBar(
        cancelLabel: l10n.showdownSkip,
        confirmLabel: l10n.showdownSave,
        onConfirm: () => Navigator.pop(context, _showdownData),
      ),
    );
  }

  Widget _buildPlayerRow(int player) {
    final playerCards = _showdownData.playerCards[player]!;
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: Border.all(color: AppColors.borderStrong, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.showdownPlayerLabel(player),
            style: AppTypography.ibm(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          _PlayerCardKeyboard(
            slots: [
              playerCards.card1 ?? '',
              playerCards.card2 ?? '',
            ],
            excludedCards: _allUsedCards,
            onCommitted: (i, card) => setState(() {
              if (i == 0) playerCards.card1 = card;
              if (i == 1) playerCards.card2 = card;
            }),
            onCleared: (i) => setState(() {
              if (i == 0) playerCards.card1 = null;
              if (i == 1) playerCards.card2 = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerSection() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: Border.all(color: AppColors.borderStrong, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.showdownWinner,
            style: AppTypography.ibm(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: widget.activePlayers.map((player) {
              final selected = _showdownData.winner == player;
              return GestureDetector(
                onTap: () => setState(() {
                  _showdownData.winner = selected ? null : player;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.bgPrimary,
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radiusFull),
                    border: Border.all(
                      color: selected
                          ? AppColors.accentPrimary
                          : AppColors.borderStrong,
                    ),
                  ),
                  child: Text(
                    l10n.showdownPlayerLabel(player),
                    style: AppTypography.ibm(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textInverse
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandDescriptionField() {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _descriptionController,
      style: AppTypography.ibm(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.showdownHandDescriptionLabel,
        hintText: l10n.showdownHandDescriptionHint,
        labelStyle: AppTypography.ibm(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.ibm(
          fontSize: 15,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          borderSide: const BorderSide(color: AppColors.accentPrimary),
        ),
      ),
      onChanged: (value) {
        _showdownData.handDescription = value.isEmpty ? null : value;
      },
    );
  }
}

/// Thin adapter around [CardKeyboard] scoped to a single player's two hole cards.
class _PlayerCardKeyboard extends StatelessWidget {
  final List<String> slots;
  final Set<String> excludedCards;
  final void Function(int slotIndex, String card) onCommitted;
  final void Function(int slotIndex) onCleared;

  const _PlayerCardKeyboard({
    required this.slots,
    required this.excludedCards,
    required this.onCommitted,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return CardKeyboard(
      slotCount: 2,
      slots: slots,
      excludedCards: excludedCards,
      onCardCommitted: onCommitted,
      onCardCleared: onCleared,
    );
  }
}
