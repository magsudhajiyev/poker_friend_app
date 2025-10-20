import 'package:flutter/material.dart';
import '../models/hand_state_machine.dart';

class AllInBoardCardsDialog extends StatefulWidget {
  final List<String> excludedCards; // Hole cards to exclude from selection
  final BoardCards? existingBoardCards; // Already selected board cards

  const AllInBoardCardsDialog({
    Key? key,
    this.excludedCards = const [],
    this.existingBoardCards,
  }) : super(key: key);

  @override
  _AllInBoardCardsDialogState createState() => _AllInBoardCardsDialogState();
}

class _AllInBoardCardsDialogState extends State<AllInBoardCardsDialog> {
  List<String> _selectedCards = ['', '', '', '', '']; // All 5 board cards
  Set<String> _currentlySelected = {};

  String? _selectedRank; // Track selected rank for two-step selection
  int? _targetSlotIndex; // Track which slot is being filled

  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  void initState() {
    super.initState();

    // Pre-fill with existing board cards if provided
    if (widget.existingBoardCards != null) {
      final board = widget.existingBoardCards!;

      // Fill flop cards (first 3 slots)
      if (board.flop.isNotEmpty) {
        for (int i = 0; i < board.flop.length && i < 3; i++) {
          if (board.flop[i].isNotEmpty) {
            _selectedCards[i] = board.flop[i];
            _currentlySelected.add(board.flop[i]);
          }
        }
      }

      // Fill turn card (4th slot)
      if (board.turn != null && board.turn!.isNotEmpty) {
        _selectedCards[3] = board.turn!;
        _currentlySelected.add(board.turn!);
      }

      // Fill river card (5th slot)
      if (board.river != null && board.river!.isNotEmpty) {
        _selectedCards[4] = board.river!;
        _currentlySelected.add(board.river!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF1F1F23),
      title: Text('All-In Board Cards', style: TextStyle(color: Colors.white)),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Complete all 5 community cards:',
                style: TextStyle(color: Colors.grey[300], fontSize: 14),
              ),
              SizedBox(height: 16),

              // Show currently selected cards
              _buildSelectedCardsRow(),

              SizedBox(height: 20),

              // Rank-then-suit selection
              _buildRankAndSuitSelection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _canSave() ? () => _saveCards() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF5AC95A),
            disabledBackgroundColor: Colors.grey[600],
          ),
          child: Text('Save Cards'),
        ),
      ],
    );
  }

  Widget _buildSelectedCardsRow() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        children: [
          // Flop cards
          Text('Flop', style: TextStyle(fontSize: 12, color: Colors.white70)),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++) ...[
                _buildCardSlot(i),
                if (i < 2) SizedBox(width: 8),
              ],
            ],
          ),
          SizedBox(height: 12),

          // Turn and River
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('Turn', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  SizedBox(height: 4),
                  _buildCardSlot(3),
                ],
              ),
              Column(
                children: [
                  Text('River', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  SizedBox(height: 4),
                  _buildCardSlot(4),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSlot(int index) {
    final card = _selectedCards[index];
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1; // Just a rank without suit

    // Check if this card was pre-filled from existing board cards
    bool isPreFilled = false;
    if (widget.existingBoardCards != null) {
      if (index < 3) {
        isPreFilled = widget.existingBoardCards!.flop.length > index &&
                      widget.existingBoardCards!.flop[index].isNotEmpty;
      } else if (index == 3) {
        isPreFilled = widget.existingBoardCards!.turn?.isNotEmpty == true;
      } else if (index == 4) {
        isPreFilled = widget.existingBoardCards!.river?.isNotEmpty == true;
      }
    }

    return GestureDetector(
      onTap: !isEmpty && !isPreFilled ? () => _clearCard(index) : null,
      child: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: isEmpty ? Colors.grey[800] : isPreFilled ? Color(0xFF2A4A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? Colors.grey[600]! : isPreFilled ? Color(0xFF3A5A3A) : Colors.grey[300]!,
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
          children: _ranks.sublist(0, 5).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
        ),
        SizedBox(height: 12),
        // Row 2: 9, 8, 7, 6, 5
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _ranks.sublist(5, 10).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
        ),
        SizedBox(height: 12),
        // Row 3: 4, 3, 2
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ..._ranks.sublist(10, 13).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
            // Add empty spacers to balance the row
            Expanded(child: Container()),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  Widget _buildRankCard(String rank) {
    // Rank cards are always selectable - exclusion happens at suit level
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => _selectRank(rank),
        child: Container(
          // Remove fixed width, let Expanded control it
          height: 70,
        decoration: BoxDecoration(
          color: Color(0xFF3A3A3E),
          border: Border.all(
            color: Color(0xFF4A4A4E),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            rank,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
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
    bool isExcluded = widget.excludedCards.contains(card) ||
                     _currentlySelected.contains(card);

    Color suitColor = _getSuitColor(suit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isExcluded ? null : () => _selectSuit(suit),
        child: Container(
          // Remove fixed width, let Expanded control it
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
      ),
    );
  }

  void _selectRank(String rank) {
    setState(() {
      _selectedRank = rank;

      // Find next empty slot that's not pre-filled
      for (int i = 0; i < _selectedCards.length; i++) {
        if (_selectedCards[i].isEmpty && !_isSlotPreFilled(i)) {
          _targetSlotIndex = i;
          _selectedCards[i] = rank; // Show just the rank temporarily
          break;
        }
      }
    });
  }

  void _selectSuit(String suit) {
    if (_selectedRank == null || _targetSlotIndex == null) return;

    String card = '$_selectedRank$suit';

    setState(() {
      // Complete the card with suit
      if (_targetSlotIndex! < _selectedCards.length) {
        // Remove old card if it was complete
        if (_selectedCards[_targetSlotIndex!].length > 1) {
          _currentlySelected.remove(_selectedCards[_targetSlotIndex!]);
        }
        _selectedCards[_targetSlotIndex!] = card;
        _currentlySelected.add(card);
      }

      // Reset selection state
      _selectedRank = null;
      _targetSlotIndex = null;
    });
  }

  bool _isSlotPreFilled(int index) {
    if (widget.existingBoardCards == null) return false;

    if (index < 3) {
      // Flop slots
      return widget.existingBoardCards!.flop.length > index &&
             widget.existingBoardCards!.flop[index].isNotEmpty;
    } else if (index == 3) {
      // Turn slot
      return widget.existingBoardCards!.turn?.isNotEmpty == true;
    } else if (index == 4) {
      // River slot
      return widget.existingBoardCards!.river?.isNotEmpty == true;
    }
    return false;
  }

  void _clearCard(int index) {
    // Don't allow clearing pre-filled cards
    if (_isSlotPreFilled(index)) return;

    setState(() {
      if (_selectedCards[index].length > 1) {
        _currentlySelected.remove(_selectedCards[index]);
      }
      _selectedCards[index] = '';

      // Clear selection state if this was the target slot
      if (_targetSlotIndex == index) {
        _selectedRank = null;
        _targetSlotIndex = null;
      }
    });
  }

  Color _getCardColor(String card) {
    if (card.length > 1) {
      final suit = card.substring(card.length - 1);
      if (suit == '♥' || suit == '♦') {
        return Colors.red[300]!;
      }
    }
    return Color(0xFFE0E0E0);
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Colors.red[300]!;
    }
    return Color(0xFFE0E0E0);
  }

  bool _canSave() {
    // All cards must be complete (rank + suit)
    return _selectedCards.every((card) => card.isNotEmpty && card.length > 1 &&
           (card.contains('♠') || card.contains('♥') || card.contains('♦') || card.contains('♣')));
  }

  void _saveCards() {
    final boardCards = BoardCards(
      flop: _selectedCards.sublist(0, 3),
      turn: _selectedCards[3],
      river: _selectedCards[4],
    );
    Navigator.pop(context, boardCards);
  }
}