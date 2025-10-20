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
  String? _selectedRank; // Track selected rank for two-step selection
  int? _targetSlotIndex; // Track which slot is being filled

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show currently selected cards
            _buildSelectedCardsRow(),

            SizedBox(height: 20),

            // Direct rank and suit selection
            _buildRankAndSuitSelection(),
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
            backgroundColor: Color(0xFF5AC95A),
            disabledBackgroundColor: Colors.grey[600],
          ),
          child: Text('Save', style: TextStyle(color: Colors.white)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentRound == BettingRound.flop) ...[
            Text('Select 3 Flop Cards:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCardSlot(0),
                _buildCardSlot(1),
                _buildCardSlot(2),
              ],
            ),
          ],

          if (widget.currentRound == BettingRound.turn) ...[
            _buildExistingCards(),
            SizedBox(height: 8),
            Text('Select Turn Card:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            _buildTurnSlot(),
          ],

          if (widget.currentRound == BettingRound.river) ...[
            _buildExistingCards(),
            SizedBox(height: 8),
            Text('Select River Card:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            _buildRiverSlot(),
          ],
        ],
      ),
    );
  }

  Widget _buildCardSlot(int index) {
    final card = _flop[index];
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
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              )
            : Center(
                child: Text(
                  isIncomplete ? card : card, // Show rank or full card
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

  Widget _buildTurnSlot() {
    final card = _turn ?? '';
    final isEmpty = card.isEmpty;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearTurn() : null,
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
                child: Icon(Icons.help_outline, color: Colors.grey[500], size: 20),
              )
            : Center(
                child: Text(
                  card,
                  style: TextStyle(
                    color: _getCardColor(card),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRiverSlot() {
    final card = _river ?? '';
    final isEmpty = card.isEmpty;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearRiver() : null,
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
                child: Icon(Icons.help_outline, color: Colors.grey[500], size: 20),
              )
            : Center(
                child: Text(
                  card,
                  style: TextStyle(
                    color: _getCardColor(card),
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
                     widget.usedCards.contains(card) ||
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

  Widget _buildExistingCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_flop.any((card) => card.isNotEmpty && card.length > 1)) ...[
          Row(
            children: [
              Text('Flop: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ..._flop.where((c) => c.isNotEmpty && c.length > 1).map((card) => Container(
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
        if (_turn != null && _turn!.isNotEmpty && _turn!.length > 1) ...[
          SizedBox(height: 4),
          Row(
            children: [
              Text('Turn: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
              Container(
                margin: EdgeInsets.only(right: 4),
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

  void _selectRank(String rank) {
    setState(() {
      _selectedRank = rank;

      // Find next empty slot and show rank immediately
      if (widget.currentRound == BettingRound.flop) {
        for (int i = 0; i < 3; i++) {
          if (_flop[i].isEmpty) {
            _targetSlotIndex = i;
            _flop[i] = rank; // Show just the rank temporarily
            break;
          }
        }
      } else if (widget.currentRound == BettingRound.turn) {
        _targetSlotIndex = 3; // Turn slot
        _turn = rank; // Show just the rank temporarily
      } else if (widget.currentRound == BettingRound.river) {
        _targetSlotIndex = 4; // River slot
        _river = rank; // Show just the rank temporarily
      }
    });
  }

  void _selectSuit(String suit) {
    if (_selectedRank == null || _targetSlotIndex == null) return;

    String card = '$_selectedRank$suit';

    setState(() {
      // Complete the card with suit
      if (widget.currentRound == BettingRound.flop && _targetSlotIndex! < 3) {
        _flop[_targetSlotIndex!] = card;
        _currentlySelected.add(card);
      } else if (widget.currentRound == BettingRound.turn) {
        _turn = card;
        _currentlySelected.add(card);
      } else if (widget.currentRound == BettingRound.river) {
        _river = card;
        _currentlySelected.add(card);
      }

      // Reset selection state
      _selectedRank = null;
      _targetSlotIndex = null;
    });
  }

  void _clearCard(int index) {
    setState(() {
      final card = _flop[index];
      if (card.isNotEmpty && card.length > 1) { // Only remove if it's a complete card
        _currentlySelected.remove(card);
      }
      _flop[index] = '';
    });
  }

  void _clearTurn() {
    setState(() {
      if (_turn != null && _turn!.length > 1) {
        _currentlySelected.remove(_turn);
      }
      _turn = '';
    });
  }

  void _clearRiver() {
    setState(() {
      if (_river != null && _river!.length > 1) {
        _currentlySelected.remove(_river);
      }
      _river = '';
    });
  }

  Color _getCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Colors.red[300]!;
    }
    return Color(0xFFE0E0E0);
  }

  String _getStreetName() {
    switch (widget.currentRound) {
      case BettingRound.flop:
        return 'Flop';
      case BettingRound.turn:
        return 'Turn';
      case BettingRound.river:
        return 'River';
      default:
        return '';
    }
  }

  bool _isValid() {
    if (widget.currentRound == BettingRound.flop) {
      // All 3 flop cards must be complete (rank + suit)
      return _flop.every((card) => card.isNotEmpty && card.length > 1);
    } else if (widget.currentRound == BettingRound.turn) {
      return _turn != null && _turn!.isNotEmpty && _turn!.length > 1;
    } else if (widget.currentRound == BettingRound.river) {
      return _river != null && _river!.isNotEmpty && _river!.length > 1;
    }
    return false;
  }

  void _saveCards() {
    // Only save complete cards (with both rank and suit)
    final validFlop = _flop.where((card) => card.isNotEmpty && card.length > 1).toList();
    final validTurn = (_turn != null && _turn!.length > 1) ? _turn : null;
    final validRiver = (_river != null && _river!.length > 1) ? _river : null;

    final boardCards = BoardCards(
      flop: widget.currentRound == BettingRound.flop ? validFlop : widget.existingCards?.flop ?? [],
      turn: widget.currentRound == BettingRound.turn ? validTurn : widget.existingCards?.turn,
      river: widget.currentRound == BettingRound.river ? validRiver : widget.existingCards?.river,
    );

    Navigator.pop(context, boardCards);
  }
}