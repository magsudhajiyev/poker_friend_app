import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';
import 'card_keyboard.dart';

class BoardCardsDialog extends StatefulWidget {
  final BettingRound currentRound;
  final BoardCards? existingCards;
  final List<String> excludedCards;
  final Set<String> usedCards;

  const BoardCardsDialog({
    Key? key,
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1B1E24), width: 1),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                // Show existing cards from previous streets (read-only)
                if (widget.currentRound != BettingRound.flop) ...[
                  _buildExistingCardsDisplay(),
                  const SizedBox(height: 12),
                ],
                // Active card keyboard for this street
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
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SvgPicture.asset(
          'icons/figma_icons/Capa_1.svg',
          width: 22,
          height: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_getStreetName()} ${widget.currentRound == BettingRound.flop ? 'Cards' : 'Card'}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.43,
            ),
          ),
        ),
      ],
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
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Center(
        child: Text(
          card,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _getCardColor(card),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final valid = _isValid();
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: valid ? _saveCards : null,
            style: TextButton.styleFrom(
              backgroundColor: valid ? const Color(0xFF89F1EC) : const Color(0xFF1B1E24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.ibmPlexSans(
                color: valid ? Colors.black : const Color(0xFF4E5054),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(
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
