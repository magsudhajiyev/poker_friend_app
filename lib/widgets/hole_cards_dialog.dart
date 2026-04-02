import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hand_state_machine.dart';

class HoleCardsDialog extends StatefulWidget {
  final HoleCards? existingCards;
  final Set<String> usedCards; // Board cards to exclude from selection
  final String title; // Dialog title
  final String? playerName; // Optional player name to highlight
  final bool isWinner; // Whether this player is a winner (shows badge)
  final bool showSkipAll; // Show "Skip All" button for remaining opponents

  const HoleCardsDialog({
    Key? key,
    this.existingCards,
    this.usedCards = const {},
    this.title = 'Your Hole Cards',
    this.playerName,
    this.isWinner = false,
    this.showSkipAll = false,
  }) : super(key: key);

  @override
  _HoleCardsDialogState createState() => _HoleCardsDialogState();
}

class _HoleCardsDialogState extends State<HoleCardsDialog> {
  late String? _card1;
  late String? _card2;
  Set<String> _currentlySelected = {};

  String? _selectedRank; // Track selected rank for two-step selection
  int? _selectedRankRow; // Track which row the selected rank is in (0, 1, or 2)
  int? _targetSlotIndex; // Track which slot is being filled (0 or 1)

  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  void initState() {
    super.initState();
    _card1 = widget.existingCards?.card1;
    _card2 = widget.existingCards?.card2;

    // Add existing selections to currently selected
    if (_card1?.isNotEmpty == true) _currentlySelected.add(_card1!);
    if (_card2?.isNotEmpty == true) _currentlySelected.add(_card2!);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF1B1E24),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Card slots
                  _buildCurrentSelections(),
                  SizedBox(height: 14),
                  // Rank and suit selection grid
                  _buildRankAndSuitSelection(),
                  SizedBox(height: 24),
                  // Actions
                  _buildActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
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
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            color: Color(0xFF89F1EC),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isWinner) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(0xFF54E98A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: Color(0xFF54E98A).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'WINNER',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              color: Color(0xFF54E98A),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hole Cards',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: Color(0xFF8C8C8C),
                    ),
                  ),
                ] else ...[
                  Text(
                    widget.title,
                    style: GoogleFonts.ibmPlexSans(
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

  Widget _buildCurrentSelections() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSelectedCardSlot(0),
        SizedBox(width: 12),
        _buildSelectedCardSlot(1),
      ],
    );
  }

  Widget _buildSelectedCardSlot(int index) {
    final card = index == 0 ? (_card1 ?? '') : (_card2 ?? '');
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;
    final isActive = _targetSlotIndex == index;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearCard(index) : null,
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: isEmpty
              ? Color(0xFF1B1E24)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Color(0xFF89F1EC)
                : isEmpty
                    ? Color(0xFF35373C)
                    : Colors.grey[400]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '?',
                  style: GoogleFonts.ibmPlexSans(
                    color: Color(0xFF4E5054),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Stack(
                children: [
                  Center(
                    child: Text(
                      card,
                      style: GoogleFonts.ibmPlexSans(
                        color: isIncomplete ? Colors.grey : _getCardColor(card),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isIncomplete)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(0xFF35373C),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildRankAndSuitSelection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF02050B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF1B1E24), width: 1),
      ),
      child: Column(
        children: [
          // Row 1: A, K, Q, J, T
          Row(
            children: _ranks.sublist(0, 5).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
          ),
          if (_selectedRank != null && _selectedRankRow == 0) ...[
            SizedBox(height: 6),
            _buildSuitSelection(),
          ],
          SizedBox(height: 6),
          // Row 2: 9, 8, 7, 6, 5
          Row(
            children: _ranks.sublist(5, 10).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
          ),
          if (_selectedRank != null && _selectedRankRow == 1) ...[
            SizedBox(height: 6),
            _buildSuitSelection(),
          ],
          SizedBox(height: 6),
          // Row 3: 4, 3, 2 (centered)
          Row(
            children: [
              Expanded(child: Container()),
              ..._ranks.sublist(10, 13).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
              Expanded(child: Container()),
            ],
          ),
          if (_selectedRank != null && _selectedRankRow == 2) ...[
            SizedBox(height: 6),
            _buildSuitSelection(),
          ],
        ],
      ),
    );
  }

  Widget _buildRankCard(String rank) {
    bool isCompletelyExcluded = _suits.every((suit) =>
        widget.usedCards.contains('$rank$suit') ||
        _currentlySelected.contains('$rank$suit'));
    bool isSelected = _selectedRank == rank;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isCompletelyExcluded ? null : () => _selectRank(rank),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isSelected
                ? Color(0xFF89F1EC).withValues(alpha: 0.15)
                : isCompletelyExcluded
                    ? Color(0xFF0A0A0E)
                    : Color(0xFF1B1E24),
            border: Border.all(
              color: isSelected
                  ? Color(0xFF89F1EC)
                  : isCompletelyExcluded
                      ? Color(0xFF1B1E24)
                      : Color(0xFF35373C),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              rank,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Color(0xFF89F1EC)
                    : isCompletelyExcluded
                        ? Color(0xFF35373C)
                        : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuitSelection() {
    return Row(
      children: _suits.map((suit) => Expanded(child: _buildSuitCard(suit))).toList(),
    );
  }

  Widget _buildSuitCard(String suit) {
    String card = '$_selectedRank$suit';
    bool isExcluded = widget.usedCards.contains(card) ||
                     _currentlySelected.contains(card);
    Color suitColor = _getSuitColor(suit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isExcluded ? null : () => _selectSuit(suit),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isExcluded ? Color(0xFF0A0A0E) : Color(0xFF1B1E24),
            border: Border.all(
              color: isExcluded ? Color(0xFF1B1E24) : Color(0xFF35373C),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedRank!,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isExcluded ? Color(0xFF35373C) : suitColor,
                  ),
                ),
                Text(
                  suit,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isExcluded ? Color(0xFF35373C) : suitColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Save button — full width mint pill
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => _saveCards(),
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFF89F1EC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        // Skip button — outline pill
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
              'Skip',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        // Skip All button - skips remaining opponents
        if (widget.showSkipAll) ...[
          SizedBox(height: 10),
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
                  borderRadius: BorderRadius.circular(40),
                  side: BorderSide(
                    color: Color(0xFFD55A41).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Skip All Remaining',
                style: GoogleFonts.ibmPlexSans(
                  color: Color(0xFFD55A41),
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

  void _selectRank(String rank) {
    setState(() {
      _selectedRank = rank;

      // Determine which row this rank is in
      int rankIndex = _ranks.indexOf(rank);
      if (rankIndex < 5) {
        _selectedRankRow = 0; // Row 1: A, K, Q, J, T
      } else if (rankIndex < 10) {
        _selectedRankRow = 1; // Row 2: 9, 8, 7, 6, 5
      } else {
        _selectedRankRow = 2; // Row 3: 4, 3, 2
      }

      // Find next empty slot and show rank immediately
      if (_card1 == null || _card1!.isEmpty) {
        _targetSlotIndex = 0;
        _card1 = rank; // Show just the rank temporarily
      } else if (_card2 == null || _card2!.isEmpty) {
        _targetSlotIndex = 1;
        _card2 = rank; // Show just the rank temporarily
      }
    });
  }

  void _selectSuit(String suit) {
    if (_selectedRank == null || _targetSlotIndex == null) return;

    String card = '$_selectedRank$suit';

    // Can only select 2 cards max
    if (_currentlySelected.length >= 2 && !_currentlySelected.contains(_card1) && !_currentlySelected.contains(_card2)) {
      return;
    }

    setState(() {
      // Complete the card with suit
      if (_targetSlotIndex == 0) {
        // Remove old card if it was complete
        if (_card1 != null && _card1!.length > 1) {
          _currentlySelected.remove(_card1);
        }
        _card1 = card;
        _currentlySelected.add(card);
      } else if (_targetSlotIndex == 1) {
        // Remove old card if it was complete
        if (_card2 != null && _card2!.length > 1) {
          _currentlySelected.remove(_card2);
        }
        _card2 = card;
        _currentlySelected.add(card);
      }

      // Reset selection state
      _selectedRank = null;
      _selectedRankRow = null;
      _targetSlotIndex = null;
    });
  }

  void _clearCard(int index) {
    setState(() {
      if (index == 0) {
        if (_card1 != null && _card1!.length > 1) {
          _currentlySelected.remove(_card1);
        }
        _card1 = '';
      } else {
        if (_card2 != null && _card2!.length > 1) {
          _currentlySelected.remove(_card2);
        }
        _card2 = '';
      }
    });
  }

  Color _getCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Color(0xFFE85D5D);
    }
    return Color(0xFF2D2D2D);
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Color(0xFFE85D5D);
    }
    return Colors.white;
  }

  void _saveCards() {
    // Helper function to check if a card is complete (has both rank and suit)
    bool isCompleteCard(String? card) {
      return card != null && card.isNotEmpty && card.length > 1 &&
             (card.contains('♠') || card.contains('♥') || card.contains('♦') || card.contains('♣'));
    }

    // Validate that both cards are selected or neither is selected
    final card1Complete = isCompleteCard(_card1);
    final card2Complete = isCompleteCard(_card2);

    if (!card1Complete && !card2Complete) {
      // Neither card selected - OK to skip
      final holeCards = HoleCards(card1: null, card2: null);
      Navigator.pop(context, holeCards);
      return;
    }

    if (card1Complete && card2Complete) {
      // Both cards selected - validate they're not the same card
      if (_card1 == _card2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You cannot select the same card twice!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Both cards selected and different - OK to save
      final holeCards = HoleCards(card1: _card1, card2: _card2);
      Navigator.pop(context, holeCards);
      return;
    }

    // One card selected but not both - show error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please select both hole cards or skip to continue'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Clear All',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _card1 = null;
              _card2 = null;
              _currentlySelected.clear();
            });
          },
        ),
      ),
    );
  }
}
