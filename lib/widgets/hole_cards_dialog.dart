import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/hand_state_machine.dart';
import '../design_system/design_system.dart';

class HoleCardsDialog extends StatefulWidget {
  final HoleCards? existingCards;
  final Set<String> usedCards; // Board cards to exclude from selection
  final String title; // Dialog title
  final String? playerName; // Optional player name to highlight
  final bool isWinner; // Whether this player is a winner (shows badge)

  const HoleCardsDialog({
    Key? key,
    this.existingCards,
    this.usedCards = const {},
    this.title = 'Your Hole Cards',
    this.playerName,
    this.isWinner = false,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.glassyCardColor(),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.whiteBorder(),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.style,
                          color: AppColors.accentGreen,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.playerName != null) ...[
                              // Highlighted player name
                              Row(
                                children: [
                                  Text(
                                    widget.playerName!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFFFFD700), // Gold/amber color
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.isWinner) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF5AC95A).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Color(0xFF5AC95A), width: 1),
                                      ),
                                      child: Text(
                                        'WINNER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF5AC95A),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Hole Cards',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ] else ...[
                              // Default title without player name
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter your hole cards (optional)',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                      SizedBox(height: 12),
                      // Show current selections at the top
                      _buildCurrentSelections(),
                      SizedBox(height: 16),
                      // Direct rank and suit selection
                      _buildRankAndSuitSelection(),
                      SizedBox(height: 20),
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.whiteBorder()),
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Color(0xFFBAFF9A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextButton(
                                onPressed: () => _saveCards(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSelections() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.whiteBorder()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select 2 Hole Cards (or skip):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
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
          color: isEmpty ? Colors.black.withOpacity(0.3) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? AppColors.whiteBorder() : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.whiteBorder()),
      ),
      child: Column(
        children: [
          // Row 1: A, K, Q, J, T
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _ranks.sublist(0, 5).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
          ),
          // Suit selection after row 1
          if (_selectedRank != null && _selectedRankRow == 0) ...[
            SizedBox(height: 8),
            _buildSuitSelection(),
          ],
          SizedBox(height: 8),
          // Row 2: 9, 8, 7, 6, 5
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _ranks.sublist(5, 10).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
          ),
          // Suit selection after row 2
          if (_selectedRank != null && _selectedRankRow == 1) ...[
            SizedBox(height: 8),
            _buildSuitSelection(),
          ],
          SizedBox(height: 8),
          // Row 3: 4, 3, 2 (centered)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: Container()), // Spacer before
              ..._ranks.sublist(10, 13).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
              Expanded(child: Container()), // Spacer after
            ],
          ),
          // Suit selection after row 3
          if (_selectedRank != null && _selectedRankRow == 2) ...[
            SizedBox(height: 8),
            _buildSuitSelection(),
          ],
        ],
      ),
    );
  }

  Widget _buildRankCard(String rank) {
    // Check if this rank is completely excluded (all suits used)
    bool isCompletelyExcluded = _suits.every((suit) =>
        widget.usedCards.contains('$rank$suit') ||
        _currentlySelected.contains('$rank$suit'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isCompletelyExcluded ? null : () => _selectRank(rank),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isCompletelyExcluded ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.3),
            border: Border.all(
              color: isCompletelyExcluded ? Colors.grey[700]! : AppColors.whiteBorder(),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  rank,
                  style: TextStyle(
                    fontSize: 20,
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
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuitSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
          height: 70,
          decoration: BoxDecoration(
            color: isExcluded ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.3),
            border: Border.all(
              color: isExcluded ? Colors.grey[700]! : AppColors.whiteBorder(),
              width: 1,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isExcluded ? Colors.grey[600] : suitColor,
                      ),
                    ),
                    Text(
                      suit,
                      style: TextStyle(
                        fontSize: 20,
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
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
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
