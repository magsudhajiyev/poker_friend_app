import 'package:flutter/material.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';

class BoardCardsDialog extends StatefulWidget {
  final BettingRound currentRound;
  final BoardCards? existingCards;
  final List<String> excludedCards; // Hole cards to exclude from selection
  final Set<String> usedCards; // Cards already committed in previous streets

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
  late List<String> _flop;
  late String? _turn;
  late String? _river;
  
  Set<String> _currentlySelected = {};

  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  void initState() {
    super.initState();
    _flop = widget.existingCards?.flop.toList() ?? ['', '', ''];
    _turn = widget.existingCards?.turn;
    _river = widget.existingCards?.river;
    
    // Add existing selections to currently selected
    _currentlySelected.addAll(_flop.where((card) => card.isNotEmpty));
    if (_turn?.isNotEmpty == true) _currentlySelected.add(_turn!);
    if (_river?.isNotEmpty == true) _currentlySelected.add(_river!);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF1F1F23),
      title: Text('${_getStreetName()} Cards', style: TextStyle(color: Colors.white)),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          child: Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isValid() ? () => _saveCards() : null,
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
          if (widget.currentRound == BettingRound.flop) ...[
            Text('Select 3 Flop Cards:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSelectedCardSlot(_flop[0], 'Flop 1'),
                _buildSelectedCardSlot(_flop[1], 'Flop 2'),
                _buildSelectedCardSlot(_flop[2], 'Flop 3'),
              ],
            ),
          ],
          
          if (widget.currentRound == BettingRound.turn) ...[
            _buildExistingCards(),
            SizedBox(height: 8),
            Text('Select Turn Card:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            _buildSelectedCardSlot(_turn ?? '', 'Turn'),
          ],
          
          if (widget.currentRound == BettingRound.river) ...[
            _buildExistingCards(),
            SizedBox(height: 8),
            Text('Select River Card:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            _buildSelectedCardSlot(_river ?? '', 'River'),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_flop.any((card) => card.isNotEmpty)) ...[
          Row(
            children: [
              Text('Flop: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ..._flop.where((c) => c.isNotEmpty).map((card) => Container(
                margin: EdgeInsets.only(right: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF3A3A3E),
                  border: Border.all(color: Color(0xFF4A4A4E)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getCardColor(card),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
            ],
          ),
        ],
        if (_turn?.isNotEmpty == true) ...[
          SizedBox(height: 4),
          Row(
            children: [
              Text('Turn: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF3A3A3E),
                  border: Border.all(color: Color(0xFF4A4A4E)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _turn!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getCardColor(_turn!),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedCardSlot(String card, String label) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white70)),
        SizedBox(height: 4),
        Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(color: card.isEmpty ? Color(0xFF4A4A4E) : Color(0xFF5A5A5E)),
            borderRadius: BorderRadius.circular(6),
            color: card.isEmpty ? Color(0xFF2A2A2E) : Color(0xFF3A3A3E),
          ),
          child: Center(
            child: Text(
              card.isEmpty ? '?' : card,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: card.isEmpty ? Colors.white54 : _getCardColor(card),
              ),
            ),
          ),
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
                    final isUsedPreviously = widget.usedCards.contains(card);
                    final isExcluded = widget.excludedCards.contains(card);
                    final isCurrentlySelected = _currentlySelected.contains(card);
                    final isDisabled = isUsedPreviously || isExcluded;
                    
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
                          color: isUsedPreviously
                            ? Color(0xFF1A1A1E) // Very dark for used cards
                            : isCurrentlySelected
                              ? Color(0xFF2A4A6E) // Blue tint for selected
                              : isExcluded
                                ? Color(0xFF2A2A2E) // Dark for excluded
                                : Color(0xFF3A3A3E), // Normal background
                        ),
                        child: Center(
                          child: Text(
                            card,
                            style: TextStyle(
                              fontSize: (cardWidth * 0.4).clamp(11, 14),
                              fontWeight: FontWeight.bold,
                              color: isUsedPreviously
                                ? Colors.grey[600] // Very faded for used cards
                                : isExcluded 
                                  ? Colors.grey[500] // Faded for excluded
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
        // Select the card
        _currentlySelected.add(card);
        _addCardToSelection(card);
      }
    });
  }

  void _addCardToSelection(String card) {
    if (widget.currentRound == BettingRound.flop) {
      // Add to first empty flop slot
      for (int i = 0; i < 3; i++) {
        if (_flop[i].isEmpty) {
          _flop[i] = card;
          break;
        }
      }
    } else if (widget.currentRound == BettingRound.turn) {
      _turn = card;
    } else if (widget.currentRound == BettingRound.river) {
      _river = card;
    }
  }

  void _removeCardFromSelection(String card) {
    if (widget.currentRound == BettingRound.flop) {
      // Remove from flop
      for (int i = 0; i < 3; i++) {
        if (_flop[i] == card) {
          _flop[i] = '';
          break;
        }
      }
    } else if (widget.currentRound == BettingRound.turn && _turn == card) {
      _turn = '';
    } else if (widget.currentRound == BettingRound.river && _river == card) {
      _river = '';
    }
  }

  Color _getCardColor(String card) {
    if (card.isEmpty) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red[300]!;
    }
    // Make spades and clubs more visible on dark background
    return Color(0xFFE0E0E0);
  }

  String _getStreetName() {
    switch (widget.currentRound) {
      case BettingRound.flop: return 'Flop';
      case BettingRound.turn: return 'Turn';
      case BettingRound.river: return 'River';
      default: return 'Board';
    }
  }

  bool _isValid() {
    switch (widget.currentRound) {
      case BettingRound.flop:
        return _flop.every((card) => card.isNotEmpty);
      case BettingRound.turn:
        return _turn != null && _turn!.isNotEmpty;
      case BettingRound.river:
        return _river != null && _river!.isNotEmpty;
      default:
        return true;
    }
  }

  void _saveCards() {
    try {
      final boardCards = BoardCards(
        flop: _flop.where((card) => card.isNotEmpty).toList(),
        turn: _turn?.isEmpty == true ? null : _turn,
        river: _river?.isEmpty == true ? null : _river,
      );
      
      Navigator.pop(context, boardCards);
    } catch (e) {
      print('Error saving board cards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}