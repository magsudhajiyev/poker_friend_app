import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import '../design_system/components/pickers/card_keyboard.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class HoleCardsDialog extends StatefulWidget {
  final HoleCards? existingCards;
  final Set<String> usedCards; // Board cards to exclude from selection
  final String? title; // Dialog title
  final String? playerName; // Optional player name to highlight
  final bool isWinner; // Whether this player is a winner (shows badge)
  final bool showSkipAll; // Show "Skip All" button for remaining opponents
  // HL-5: players often show only ONE card — allow saving a single card
  // (shown-cards recording). Default false: normal flows still require both.
  final bool allowSingleCard;

  const HoleCardsDialog({
    Key? key,
    this.existingCards,
    this.usedCards = const {},
    this.title,
    this.playerName,
    this.isWinner = false,
    this.showSkipAll = false,
    this.allowSingleCard = false,
  }) : super(key: key);

  @override
  _HoleCardsDialogState createState() => _HoleCardsDialogState();
}

class _HoleCardsDialogState extends State<HoleCardsDialog> {
  late List<String> _slots; // 2 slots
  Set<String> _currentlySelected = {};

  @override
  void initState() {
    super.initState();
    final c1 = widget.existingCards?.card1 ?? '';
    final c2 = widget.existingCards?.card2 ?? '';
    _slots = [c1, c2];
    if (c1.isNotEmpty && c1.length > 1) _currentlySelected.add(c1);
    if (c2.isNotEmpty && c2.length > 1) _currentlySelected.add(c2);
  }

  Set<String> get _allExcluded => {...widget.usedCards, ..._currentlySelected};

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      padding: EdgeInsets.zero,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CardKeyboard(
                  slotCount: 2,
                  slots: _slots,
                  excludedCards: _allExcluded,
                  onCardCommitted: _onCardCommitted,
                  onCardCleared: _onCardCleared,
                ),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(
              context,
              HoleCards(card1: 'GO_BACK', card2: 'GO_BACK'),
            ),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.neutral700,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.playerName != null) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.playerName!,
                          style: AppTypography.ibm(
                            fontSize: 17,
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isWinner) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF54E98A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                            border: Border.all(
                              color: const Color(0xFF54E98A).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            l10n.holeCardsWinnerBadge,
                            style: AppTypography.ibm(
                              fontSize: 10,
                              color: const Color(0xFF54E98A),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.holeCardsSubtitle,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ] else ...[
                  Text(
                    widget.title ?? l10n.holeCardsTitle,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Save button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _saveCards,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.holeCardsSave,
              style: AppTypography.ibm(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Skip button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.holeCardsSkip,
              style: AppTypography.ibm(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        if (widget.showSkipAll) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(
                context,
                HoleCards(card1: 'SKIP_ALL', card2: 'SKIP_ALL'),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                  side: BorderSide(
                    color: AppColors.errorRed.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                l10n.holeCardsSkipAllRemaining,
                style: AppTypography.ibm(
                  color: AppColors.errorRed,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _onCardCommitted(int slotIndex, String card) {
    setState(() {
      _slots[slotIndex] = card;
      _currentlySelected.add(card);
    });
  }

  void _onCardCleared(int slotIndex) {
    setState(() {
      final old = _slots[slotIndex];
      if (old.isNotEmpty && old.length > 1) _currentlySelected.remove(old);
      _slots[slotIndex] = '';
    });
  }

  void _saveCards() {
    bool isComplete(String card) =>
        card.isNotEmpty && card.length > 1 &&
        (card.contains('♠') || card.contains('♥') || card.contains('♦') || card.contains('♣'));

    final c1 = isComplete(_slots[0]);
    final c2 = isComplete(_slots[1]);

    if (!c1 && !c2) {
      Navigator.pop(context, HoleCards(card1: null, card2: null));
      return;
    }

    if (c1 && c2) {
      if (_slots[0] == _slots[1]) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.holeCardsDuplicateCardError), backgroundColor: Colors.red),
        );
        return;
      }
      Navigator.pop(context, HoleCards(card1: _slots[0], card2: _slots[1]));
      return;
    }

    // HL-5: a single shown card is a valid save when allowed.
    if (widget.allowSingleCard) {
      Navigator.pop(
          context,
          HoleCards(
            card1: c1 ? _slots[0] : (c2 ? _slots[1] : null),
            card2: null,
          ));
      return;
    }

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.holeCardsSelectBothOrSkip),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: l10n.holeCardsClearAll,
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _slots = ['', ''];
              _currentlySelected.clear();
            });
          },
        ),
      ),
    );
  }
}
