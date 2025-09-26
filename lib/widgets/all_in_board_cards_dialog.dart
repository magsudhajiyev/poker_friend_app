import 'package:flutter/material.dart';
import '../models/hand_state_machine.dart';

class AllInBoardCardsDialog extends StatefulWidget {
  final List<String> excludedCards; // Hole cards to exclude from selection

  const AllInBoardCardsDialog({
    Key? key,
    this.excludedCards = const [],
  }) : super(key: key);

  @override
  _AllInBoardCardsDialogState createState() => _AllInBoardCardsDialogState();
}

class _AllInBoardCardsDialogState extends State<AllInBoardCardsDialog> {
  List<String> _selectedCards = ['', '', '', '', '']; // All 5 board cards
  Set<String> _currentlySelected = {};

  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF1F1F23),
      title: Text('All-In Board Cards', style: TextStyle(color: Colors.white)),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select all 5 community cards (Flop, Turn, River):',
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
            SizedBox(height: 16),

            // Show currently selected cards
            _buildSelectedCardsRow(),

            SizedBox(height: 20),

            // Card selection grid
            Container(
              height: 300,
              child: _buildCardGrid(),
            ),
          ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < 5; i++)
            _buildCardSlot(i),
        ],
      ),
    );
  }

  Widget _buildCardSlot(int index) {
    final card = _selectedCards[index];
    final isEmpty = card.isEmpty;

    return Container(
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
                card,
                style: TextStyle(
                  color: _getCardColor(card),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Color _getCardColor(String card) {
    if (card.length > 1) {
      final suit = card.substring(1);
      if (suit == '♥' || suit == '♦') {
        return Colors.red;
      }
    }
    return Colors.black;
  }

  Widget _buildCardGrid() {
    List<Widget> cardWidgets = [];

    for (String suit in _suits) {
      for (String rank in _ranks) {
        String card = '$rank$suit';
        bool isExcluded = widget.excludedCards.contains(card);
        bool isSelected = _currentlySelected.contains(card);

        cardWidgets.add(
          GestureDetector(
            onTap: isExcluded ? null : () => _toggleCard(card),
            child: Container(
              width: 35,
              height: 50,
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isExcluded
                    ? Colors.grey[700]
                    : isSelected
                        ? Color(0xFF5AC95A)
                        : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isExcluded
                      ? Colors.grey[600]!
                      : isSelected
                          ? Color(0xFF4A9F4A)
                          : Colors.grey[300]!,
                ),
              ),
              child: Center(
                child: Text(
                  card,
                  style: TextStyle(
                    color: isExcluded
                        ? Colors.grey[500]
                        : isSelected
                            ? Colors.white
                            : _getCardColor(card),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return GridView.count(
      crossAxisCount: 13, // 13 ranks per row
      childAspectRatio: 35/50,
      children: cardWidgets,
    );
  }

  void _toggleCard(String card) {
    setState(() {
      if (_currentlySelected.contains(card)) {
        // Remove card
        _currentlySelected.remove(card);
        // Find and clear from selected cards array
        for (int i = 0; i < _selectedCards.length; i++) {
          if (_selectedCards[i] == card) {
            _selectedCards[i] = '';
            break;
          }
        }
      } else if (_currentlySelected.length < 5) {
        // Add card to first empty slot
        for (int i = 0; i < _selectedCards.length; i++) {
          if (_selectedCards[i].isEmpty) {
            _selectedCards[i] = card;
            _currentlySelected.add(card);
            break;
          }
        }
      }
    });
  }

  bool _canSave() {
    return _currentlySelected.length == 5;
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