import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';

class ShowdownDialog extends StatefulWidget {
  final int playerCount;
  final List<int> activePlayers; // Players who reached showdown
  final ShowdownData? existingData;

  const ShowdownDialog({
    Key? key,
    required this.playerCount,
    required this.activePlayers,
    this.existingData,
  }) : super(key: key);

  @override
  _ShowdownDialogState createState() => _ShowdownDialogState();
}

class _ShowdownDialogState extends State<ShowdownDialog> {
  late ShowdownData _showdownData;
  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  void initState() {
    super.initState();
    _showdownData = widget.existingData ?? ShowdownData();
    
    // Initialize empty hole cards for active players if not already set
    for (int player in widget.activePlayers) {
      _showdownData.playerCards[player] ??= HoleCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.showdownTitle),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.showdownEnterOpponentCards),
              SizedBox(height: 16),
              
              // Player cards section
              ...widget.activePlayers.map((player) => _buildPlayerSection(player)),
              
              SizedBox(height: 16),
              
              // Winner selection
              _buildWinnerSection(),
              
              SizedBox(height: 16),
              
              // Hand description (optional)
              _buildHandDescriptionSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.showdownSkip),
        ),
        ElevatedButton(
          onPressed: () => _saveShowdown(),
          child: Text(l10n.showdownSave),
        ),
      ],
    );
  }

  Widget _buildPlayerSection(int player) {
    final playerCards = _showdownData.playerCards[player]!;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).showdownPlayerLabel(player), style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPlayerCardSelector(
                player,
                AppLocalizations.of(context).showdownCard1,
                playerCards.card1 ?? '',
                (card) => setState(() => playerCards.card1 = card.isEmpty ? null : card)
              ),
              _buildPlayerCardSelector(
                player,
                AppLocalizations.of(context).showdownCard2,
                playerCards.card2 ?? '',
                (card) => setState(() => playerCards.card2 = card.isEmpty ? null : card)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCardSelector(int player, String label, String currentCard, Function(String) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12)),
        SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showCardPicker(onChanged),
          child: Container(
            width: 50,
            height: 65,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(6),
              color: currentCard.isEmpty ? Colors.grey[100] : Colors.white,
            ),
            child: Center(
              child: Text(
                currentCard.isEmpty ? '?' : currentCard,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getCardColor(currentCard),
                ),
              ),
            ),
          ),
        ),
        if (currentCard.isNotEmpty)
          TextButton(
            onPressed: () => onChanged(''),
            child: Text(AppLocalizations.of(context).showdownClear, style: TextStyle(fontSize: 8)),
          ),
      ],
    );
  }

  Widget _buildWinnerSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).showdownWinner, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Wrap(
            children: widget.activePlayers.map((player) {
              return Container(
                margin: EdgeInsets.only(right: 8, bottom: 4),
                child: ChoiceChip(
                  label: Text(AppLocalizations.of(context).showdownPlayerLabel(player)),
                  selected: _showdownData.winner == player,
                  onSelected: (selected) {
                    setState(() {
                      _showdownData.winner = selected ? player : null;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandDescriptionSection() {
    return Container(
      width: double.infinity,
      child: TextField(
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).showdownHandDescriptionLabel,
          hintText: AppLocalizations.of(context).showdownHandDescriptionHint,
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          _showdownData.handDescription = value.isEmpty ? null : value;
        },
        controller: TextEditingController(text: _showdownData.handDescription),
      ),
    );
  }

  void _showCardPicker(Function(String) onChanged) {
    // Collect all already selected cards to exclude them
    List<String> excludedCards = [];
    for (var playerCards in _showdownData.playerCards.values) {
      if (playerCards.card1 != null && playerCards.card1!.isNotEmpty) {
        excludedCards.add(playerCards.card1!);
      }
      if (playerCards.card2 != null && playerCards.card2!.isNotEmpty) {
        excludedCards.add(playerCards.card2!);
      }
    }

    showDialog(
      context: context,
      builder: (context) => _CardPickerDialog(
        onCardSelected: onChanged,
        excludedCards: excludedCards,
      ),
    );
  }

  Color _getCardColor(String card) {
    if (card.isEmpty) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  void _saveShowdown() {
    Navigator.pop(context, _showdownData);
  }
}

class _CardPickerDialog extends StatelessWidget {
  final Function(String) onCardSelected;
  final List<String> excludedCards;

  const _CardPickerDialog({
    required this.onCardSelected,
    this.excludedCards = const [],
  });

  final List<String> _suits = const ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = const ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).showdownSelectCard),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.7,
          ),
          itemCount: 52,
          itemBuilder: (context, index) {
            final suit = _suits[index % 4];
            final rank = _ranks[index ~/ 4];
            final card = '$rank$suit';
            final isExcluded = excludedCards.contains(card);
            
            return GestureDetector(
              onTap: isExcluded ? null : () {
                onCardSelected(card);
                Navigator.pop(context);
              },
              child: Container(
                margin: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: isExcluded ? Colors.grey[300]! : Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: isExcluded ? Colors.grey[200] : Colors.white,
                ),
                child: Center(
                  child: Text(
                    card,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isExcluded 
                        ? Colors.grey
                        : (suit == '♥' || suit == '♦') ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
      ],
    );
  }
}