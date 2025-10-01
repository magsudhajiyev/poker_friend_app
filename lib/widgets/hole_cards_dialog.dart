import 'package:flutter/material.dart';
import '../models/hand_state_machine.dart';

class HoleCardsDialog extends StatefulWidget {
  final HoleCards? existingCards;
  final Set<String> usedCards; // Board cards to exclude from selection

  const HoleCardsDialog({
    Key? key,
    this.existingCards,
    this.usedCards = const {},
  }) : super(key: key);

  @override
  _HoleCardsDialogState createState() => _HoleCardsDialogState();
}

class _HoleCardsDialogState extends State<HoleCardsDialog> {
  late String? _card1;
  late String? _card2;
  Set<String> _currentlySelected = {};

  String? _selectedRank; // Track selected rank for two-step selection
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
    return AlertDialog(
      backgroundColor: Color(0xFF1F1F23),
      title: Text('Your Hole Cards', style: TextStyle(color: Colors.white)),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your hole cards (optional)', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),

            // Show current selections at the top
            _buildCurrentSelections(),

            SizedBox(height: 20),

            // Direct rank and suit selection
            _buildRankAndSuitSelection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Skip', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => _saveCards(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2A2A2E),
          ),
          child: Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildCurrentSelections() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select 2 Hole Cards (or skip):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSelectedCardSlot(0),
              _buildSelectedCardSlot(1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCardSlot(int index) {
    final card = index == 0 ? (_card1 ?? '') : (_card2 ?? '');
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1; // Just a rank without suit

    return GestureDetector(
      onTap: !isEmpty ? () => _clearCard(index) : null,
      child: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: isEmpty ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? Colors.grey[600]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 20,
                  ),
                ),
              )
            : Center(
                child: Text(
                  card,
                  style: TextStyle(
                    color: isIncomplete ? Colors.grey : _getCardColor(card),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRankAndSuitSelection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3A3A3E)),
      ),
      child: Column(
        children: [
          // Rank selection
          _buildRankSelection(),
          SizedBox(height: 20),
          // Suit selection (only shown after rank is selected)
          if (_selectedRank != null) _buildSuitSelection(),
        ],
      ),
    );
  }

  Widget _buildRankSelection() {
    return Column(
      children: [
        // Row 1: A, K, Q, J, T
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _ranks.sublist(0, 5).map((rank) => _buildRankCard(rank)).toList(),
        ),
        SizedBox(height: 12),
        // Row 2: 9, 8, 7, 6, 5
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _ranks.sublist(5, 10).map((rank) => _buildRankCard(rank)).toList(),
        ),
        SizedBox(height: 12),
        // Row 3: 4, 3, 2
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ..._ranks.sublist(10, 13).map((rank) => _buildRankCard(rank)).toList(),
            // Add empty spacers to center the 3 cards
            Container(width: 50),
            Container(width: 50),
          ],
        ),
      ],
    );
  }

  Widget _buildRankCard(String rank) {
    // Check if this rank is completely excluded (all suits used)
    bool isCompletelyExcluded = _suits.every((suit) =>
        widget.usedCards.contains('$rank$suit') ||
        _currentlySelected.contains('$rank$suit'));

    return GestureDetector(
      onTap: isCompletelyExcluded ? null : () => _selectRank(rank),
      child: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: isCompletelyExcluded ? Color(0xFF2A2A2E) : Color(0xFF3A3A3E),
          border: Border.all(
            color: isCompletelyExcluded ? Color(0xFF3A3A3E) : Color(0xFF4A4A4E),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                rank,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isCompletelyExcluded ? Colors.grey[600] : Colors.white,
                ),
              ),
            ),
            if (isCompletelyExcluded)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.close,
                  color: Colors.red[400],
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuitSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _suits.map((suit) => _buildSuitCard(suit)).toList(),
    );
  }

  Widget _buildSuitCard(String suit) {
    String card = '$_selectedRank$suit';
    bool isExcluded = widget.usedCards.contains(card) ||
                     _currentlySelected.contains(card);

    Color suitColor = _getSuitColor(suit);

    return GestureDetector(
      onTap: isExcluded ? null : () => _selectSuit(suit),
      child: Container(
        width: 60,
        height: 85,
        decoration: BoxDecoration(
          color: isExcluded ? Color(0xFF2A2A2E) : Color(0xFF3A3A3E),
          border: Border.all(
            color: isExcluded ? Color(0xFF3A3A3E) : Color(0xFF4A4A4E),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedRank!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isExcluded ? Colors.grey[600] : suitColor,
                    ),
                  ),
                  Text(
                    suit,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isExcluded ? Colors.grey[600] : suitColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isExcluded)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.close,
                  color: Colors.red[400],
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectRank(String rank) {
    setState(() {
      _selectedRank = rank;

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
      return Colors.red[300]!;
    }
    // Make spades and clubs more visible on dark background
    return Color(0xFFE0E0E0); // Light gray instead of white for better visibility
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Colors.red[300]!;
    }
    return Color(0xFFE0E0E0);
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