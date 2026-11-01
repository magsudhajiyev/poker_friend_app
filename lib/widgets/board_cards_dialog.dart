import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import 'easy_logging/board_add_later_bar.dart';
import '../models/poker_game_state.dart';
import '../design_system/components/pickers/card_keyboard.dart';
import '../design_system/components/cards/suit_icon.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class BoardCardsDialog extends StatefulWidget {
  final BettingRound currentRound;
  final BoardCards? existingCards;
  final List<String> excludedCards;
  final Set<String> usedCards;

  /// Easy logging: offer "Add later" (pops a [BoardAddLater]) and confirm
  /// automatically when the last card of the street is picked.
  final bool allowAddLater;
  final bool autoConfirm;

  const BoardCardsDialog({
    Key? key,
    this.allowAddLater = false,
    this.autoConfirm = false,
    required this.currentRound,
    this.existingCards,
    this.excludedCards = const [],
    this.usedCards = const {},
  }) : super(key: key);

  @override
  _BoardCardsDialogState createState() => _BoardCardsDialogState();
}

class _BoardCardsDialogState extends State<BoardCardsDialog> {
  late List<String> _slots; // Active slots for current street
  Set<String> _currentlySelected = {};

  @override
  void initState() {
    super.initState();
    if (widget.currentRound == BettingRound.flop) {
      final existingFlop = widget.existingCards?.flop ?? [];
      _slots = List.generate(3, (i) => i < existingFlop.length ? existingFlop[i] : '');
    } else if (widget.currentRound == BettingRound.turn) {
      _slots = [widget.existingCards?.turn ?? ''];
    } else {
      _slots = [widget.existingCards?.river ?? ''];
    }

    for (final card in _slots) {
      if (card.isNotEmpty && card.length > 1) _currentlySelected.add(card);
    }
  }

  Set<String> get _allExcluded => {
    ...widget.excludedCards,
    ...widget.usedCards,
    ..._currentlySelected,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        '${_getStreetName()} ${widget.currentRound == BettingRound.flop ? l10n.boardCardsCards : l10n.boardCardsCard}';
    return AppDialog(
      title: title,
      showCloseButton: false,
      padding: const EdgeInsets.all(20),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentRound != BettingRound.flop) ...[
            _buildExistingCardsDisplay(),
            const SizedBox(height: 12),
          ],
          CardKeyboard(
            slotCount: _slots.length,
            slots: _slots,
            excludedCards: _allExcluded,
            onCardCommitted: _onCardCommitted,
            onCardCleared: _onCardCleared,
          ),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Read-only display of cards from previous streets.
  Widget _buildExistingCardsDisplay() {
    final existingFlop = widget.existingCards?.flop ?? [];
    final existingTurn = widget.existingCards?.turn;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Flop cards (always shown for turn/river)
        ...existingFlop.where((c) => c.isNotEmpty && c.length > 1).map((card) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _buildReadOnlyCard(card),
          );
        }),
        // Turn card (shown for river)
        if (widget.currentRound == BettingRound.river && existingTurn != null && existingTurn.length > 1) ...[
          const SizedBox(width: 3),
          _buildReadOnlyCard(existingTurn),
        ],
      ],
    );
  }

  Widget _buildReadOnlyCard(String card) {
    final rank = card.length > 1 ? card.substring(0, card.length - 1) : card;
    final suitChar = card.length > 1 ? card[card.length - 1] : null;
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _getCardColor(card),
            ),
          ),
          if (suitChar != null) ...[
            const SizedBox(height: 2),
            SuitIcon(suitChar: suitChar, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context);
    final valid = _isValid();
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: valid ? _saveCards : null,
            style: TextButton.styleFrom(
              backgroundColor: valid ? AppColors.accentPrimary : AppColors.neutral800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.commonSave,
              style: AppTypography.ibm(
                color: valid ? Colors.black : AppColors.infoCardDateText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        if (widget.allowAddLater) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(context, const BoardAddLater()),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                l10n.easyLogBoardAddLater,
                style: AppTypography.ibm(
                  color: AppColors.accentPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
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
              l10n.commonCancel,
              style: AppTypography.ibm(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _autoSaved = false;

  void _onCardCommitted(int slotIndex, String card) {
    setState(() {
      _slots[slotIndex] = card;
      _currentlySelected.add(card);
    });
    if (widget.autoConfirm && _isValid() && !_autoSaved) {
      _autoSaved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveCards();
      });
    }
  }

  void _onCardCleared(int slotIndex) {
    setState(() {
      final old = _slots[slotIndex];
      if (old.isNotEmpty && old.length > 1) _currentlySelected.remove(old);
      _slots[slotIndex] = '';
    });
  }

  Color _getCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) return const Color(0xFFE85D5D);
    return const Color(0xFF2D2D2D);
  }

  String _getStreetName() {
    switch (widget.currentRound) {
      case BettingRound.flop: return 'Flop';
      case BettingRound.turn: return 'Turn';
      case BettingRound.river: return 'River';
      default: return '';
    }
  }

  bool _isValid() {
    return _slots.every((card) => card.isNotEmpty && card.length > 1);
  }

  void _saveCards() {
    final validCards = _slots.where((c) => c.isNotEmpty && c.length > 1).toList();

    final boardCards = BoardCards(
      flop: widget.currentRound == BettingRound.flop
          ? validCards
          : widget.existingCards?.flop ?? [],
      turn: widget.currentRound == BettingRound.turn
          ? validCards.first
          : widget.existingCards?.turn,
      river: widget.currentRound == BettingRound.river
          ? validCards.first
          : widget.existingCards?.river,
    );

    Navigator.pop(context, boardCards);
  }
}
