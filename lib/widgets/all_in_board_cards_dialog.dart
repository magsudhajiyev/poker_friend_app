import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/hand_state_machine.dart';
import '../design_system/design_system.dart';

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
  int? _selectedRankRow; // Track which row the selected rank is in (0, 1, or 2)
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
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
                          Icons.casino,
                          color: AppColors.accentGreen,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'All-In Board Cards',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Complete all 5 community cards:',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          ),
                          SizedBox(height: 12),
                          // Show currently selected cards
                          _buildSelectedCardsRow(),
                          SizedBox(height: 16),
                          // Rank-then-suit selection
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
                                      'Cancel',
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
                                    color: _canSave() ? Color(0xFFBAFF9A) : Colors.grey[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TextButton(
                                    onPressed: _canSave() ? () => _saveCards() : null,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Save Cards',
                                      style: TextStyle(
                                        color: _canSave() ? Colors.black : Colors.white.withOpacity(0.5),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedCardsRow() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.whiteBorder()),
      ),
      child: Column(
        children: [
          // Flop cards
          Text('Flop', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
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
                  Text('Turn', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                  SizedBox(height: 4),
                  _buildCardSlot(3),
                ],
              ),
              Column(
                children: [
                  Text('River', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
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
          color: isEmpty ? Colors.black.withOpacity(0.3) : isPreFilled ? Color(0xFF2A4A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? AppColors.whiteBorder() : isPreFilled ? Color(0xFF3A5A3A) : Colors.grey[300]!,
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
    // Rank cards are always selectable - exclusion happens at suit level
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => _selectRank(rank),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.all(
              color: AppColors.whiteBorder(),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              rank,
              style: TextStyle(
                fontSize: 20,
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
      _selectedRankRow = null;
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
