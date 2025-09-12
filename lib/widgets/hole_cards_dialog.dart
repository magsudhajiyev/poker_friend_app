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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your hole cards (optional)', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            
            // Show current selections at the top
            _buildCurrentSelections(),
            
            SizedBox(height: 16),
            
            // Card grid
            Expanded(
              child: _buildCardGrid(),
            ),
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
        color: Color(0xFF2A2A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3A3A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select 2 Hole Cards (or skip):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSelectedCardSlot(_card1 ?? '', 'Card 1'),
              _buildSelectedCardSlot(_card2 ?? '', 'Card 2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCardSlot(String card, String label) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.white70)),
        SizedBox(height: 2),
        GestureDetector(
          onTap: card.isNotEmpty ? () => _clearCard(card) : null,
          child: Container(
            width: 40,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: card.isEmpty ? Color(0xFF4A4A4E) : Color(0xFF5A5A5E)),
              borderRadius: BorderRadius.circular(6),
              color: card.isEmpty ? Color(0xFF2A2A2E) : Color(0xFF3A3A3E),
            ),
            child: Center(
              child: Text(
                card.isEmpty ? '?' : card,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: card.isEmpty ? Colors.white54 : _getCardColor(card),
                ),
              ),
            ),
          ),
        ),
        if (card.isNotEmpty)
          TextButton(
            onPressed: () => _clearCard(card),
            child: Text('Clear', style: TextStyle(fontSize: 7, color: Colors.white54)),
          ),
      ],
    );
  }

  Widget _buildCardGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3A3A3E)),
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Compact 4-row layout, one row per suit
          ..._suits.map((suit) => Expanded(child: _buildSuitRow(suit))),
        ],
      ),
    );
  }

  Widget _buildSuitRow(String suit) {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Suit icon with better visibility
          Container(
            width: 24,
            child: Text(
              suit,
              style: TextStyle(
                color: _getSuitColor(suit),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 8),
          // Cards in this suit
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate card size based on available width with tighter spacing
                final availableWidth = constraints.maxWidth;
                final cardWidth = (availableWidth - (12 * 2)) / 13; // 13 cards, 12 spaces of 2px each
                final cardHeight = cardWidth * 1.5; // Slightly taller aspect ratio
                
                return Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: _ranks.map((rank) {
                    final card = '$rank$suit';
                    final isUsedInBoard = widget.usedCards.contains(card);
                    final isCurrentlySelected = _currentlySelected.contains(card);
                    final isDisabled = isUsedInBoard;
                    
                    return GestureDetector(
                      onTap: isDisabled ? null : () => _toggleCard(card),
                      child: Container(
                        width: cardWidth.clamp(26, 36),
                        height: cardHeight.clamp(35, 54),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isCurrentlySelected 
                              ? Colors.blue
                              : isDisabled 
                                ? Color(0xFF3A3A3E) 
                                : Color(0xFF4A4A4E),
                            width: isCurrentlySelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: isUsedInBoard
                            ? Color(0xFF1A1A1E) // Very dark for used cards
                            : isCurrentlySelected
                              ? Color(0xFF2A4A6E) // Blue tint for selected
                              : Color(0xFF3A3A3E), // Normal background
                        ),
                        child: Center(
                          child: Text(
                            card,
                            style: TextStyle(
                              fontSize: (cardWidth * 0.4).clamp(11, 14),
                              fontWeight: FontWeight.bold,
                              color: isUsedInBoard
                                ? Colors.grey[600] // Very faded for used cards
                                : isCurrentlySelected
                                  ? Colors.white // White for selected
                                  : _getCardColor(card), // Normal color for available
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Colors.red[300]!;
    }
    // Make spades and clubs more visible on dark background
    return Color(0xFFE0E0E0); // Light gray instead of white for better visibility
  }

  void _toggleCard(String card) {
    setState(() {
      if (_currentlySelected.contains(card)) {
        // Deselect the card
        _currentlySelected.remove(card);
        _removeCardFromSelection(card);
      } else {
        // Can only select 2 cards max
        if (_currentlySelected.length < 2) {
          _currentlySelected.add(card);
          _addCardToSelection(card);
        }
      }
    });
  }

  void _addCardToSelection(String card) {
    if (_card1 == null || _card1!.isEmpty) {
      _card1 = card;
    } else if (_card2 == null || _card2!.isEmpty) {
      _card2 = card;
    } else {
      // Both slots are full - this shouldn't happen due to UI logic
      print('Warning: Trying to add card when both slots are full');
    }
  }

  void _removeCardFromSelection(String card) {
    if (_card1 == card) {
      _card1 = '';
    } else if (_card2 == card) {
      _card2 = '';
    }
  }

  void _clearCard(String card) {
    setState(() {
      _currentlySelected.remove(card);
      _removeCardFromSelection(card);
    });
  }

  Color _getCardColor(String card) {
    if (card.isEmpty) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red[300]!;
    }
    // Make spades and clubs more visible on dark background
    return Color(0xFFE0E0E0);
  }

  void _saveCards() {
    // Validate that both cards are selected or neither is selected
    final card1Empty = _card1?.isEmpty == true || _card1 == null;
    final card2Empty = _card2?.isEmpty == true || _card2 == null;
    
    if (card1Empty && card2Empty) {
      // Neither card selected - OK to skip
      final holeCards = HoleCards(card1: null, card2: null);
      Navigator.pop(context, holeCards);
      return;
    }
    
    if (!card1Empty && !card2Empty) {
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