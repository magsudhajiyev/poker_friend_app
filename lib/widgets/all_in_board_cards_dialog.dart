import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 361),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.15),
              blurRadius: 64,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                SizedBox(height: 16),
                // Selected Cards Section
                _buildSelectedCardsSection(),
                SizedBox(height: 8),
                // Card Grid Section
                _buildCardGridSection(),
                SizedBox(height: 24),
                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Cards icon
          SvgPicture.asset(
            'icons/figma_icons/Capa_1.svg',
            width: 24,
            height: 24,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'All-In Board Cards',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.43,
                height: 22 / 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCardsSection() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select all 5 community cards:',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),
          // Flop row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Flop',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCardSlot(0),
              SizedBox(width: 8),
              _buildCardSlot(1),
              SizedBox(width: 8),
              _buildCardSlot(2),
            ],
          ),
          SizedBox(height: 12),
          // Turn and River row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    'Turn',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 6),
                  _buildCardSlot(3),
                ],
              ),
              SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    'River',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 6),
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
        width: 48,
        height: 62,
        decoration: BoxDecoration(
          color: isPreFilled ? Color(0xFF2A4A2A) : Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isEmpty
              ? Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.8),
                  ),
                )
              : Text(
                  card,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isIncomplete ? Colors.white.withOpacity(0.5) : _getCardColor(card),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCardGridSection() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Row 1: A, K, Q, J, T
          _buildRankRow(_ranks.sublist(0, 5)),
          // Suit selection after row 1
          if (_selectedRank != null && _selectedRankRow == 0) ...[
            SizedBox(height: 8),
            _buildSuitSelectionRow(),
          ],
          SizedBox(height: 8),
          // Row 2: 9, 8, 7, 6, 5
          _buildRankRow(_ranks.sublist(5, 10)),
          // Suit selection after row 2
          if (_selectedRank != null && _selectedRankRow == 1) ...[
            SizedBox(height: 8),
            _buildSuitSelectionRow(),
          ],
          SizedBox(height: 8),
          // Row 3: 4, 3, 2 (centered with padding)
          _buildCenteredRankRow(_ranks.sublist(10, 13)),
          // Suit selection after row 3
          if (_selectedRank != null && _selectedRankRow == 2) ...[
            SizedBox(height: 8),
            _buildSuitSelectionRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildRankRow(List<String> ranks) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ranks.map((rank) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: _buildRankCard(rank),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCenteredRankRow(List<String> ranks) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Spacer(),
        ...ranks.map((rank) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: _buildRankCard(rank),
            ),
          );
        }).toList(),
        Spacer(),
      ],
    );
  }

  Widget _buildRankCard(String rank) {
    return GestureDetector(
      onTap: () => _selectRank(rank),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            rank,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuitSelectionRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _suits.map((suit) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: _buildSuitCard(suit),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuitCard(String suit) {
    String card = '$_selectedRank$suit';
    bool isExcluded = widget.excludedCards.contains(card) ||
                     _currentlySelected.contains(card);

    Color suitColor = _getSuitColor(suit);

    return GestureDetector(
      onTap: isExcluded ? null : () => _selectSuit(suit),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _selectedRank!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isExcluded ? Colors.grey[600] : Colors.white,
              ),
            ),
            Text(
              suit,
              style: TextStyle(
                fontSize: 24,
                color: isExcluded ? Colors.grey[600] : suitColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Cancel Button
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 14),
          // Save Button
          Expanded(
            child: GestureDetector(
              onTap: _canSave() ? () => _saveCards() : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _canSave() ? Color(0xFF62E3BC) : Colors.grey[700],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _canSave() ? Colors.black : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    if (card.isEmpty || card.length == 1) return Colors.white;
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.white;
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Colors.red;
    }
    return Colors.white;
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
