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

      if (board.flop.isNotEmpty) {
        for (int i = 0; i < board.flop.length && i < 3; i++) {
          if (board.flop[i].isNotEmpty) {
            _selectedCards[i] = board.flop[i];
            _currentlySelected.add(board.flop[i]);
          }
        }
      }

      if (board.turn != null && board.turn!.isNotEmpty) {
        _selectedCards[3] = board.turn!;
        _currentlySelected.add(board.turn!);
      }

      if (board.river != null && board.river!.isNotEmpty) {
        _selectedCards[4] = board.river!;
        _currentlySelected.add(board.river!);
      }
    }
  }

  // All excluded cards: hero hole cards + already selected board cards
  Set<String> get _allExcluded {
    final excluded = <String>{};
    excluded.addAll(widget.excludedCards);
    excluded.addAll(_currentlySelected);
    return excluded;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF1B1E24),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 16),
                _buildSelectedCardsSection(),
                SizedBox(height: 12),
                _buildCardGridSection(),
                SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SvgPicture.asset(
          'icons/figma_icons/Capa_1.svg',
          width: 22,
          height: 22,
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCardsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF02050B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF1B1E24), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select all 5 community cards:',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),
          // Flop label
          Center(
            child: Text(
              'Flop',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Color(0xFF8C8C8C),
              ),
            ),
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
                      color: Color(0xFF8C8C8C),
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
                      color: Color(0xFF8C8C8C),
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
    final isIncomplete = card.length == 1;
    final isActive = _targetSlotIndex == index;

    // Check if this card was pre-filled from existing board cards
    bool isPreFilled = _isSlotPreFilled(index);

    return GestureDetector(
      onTap: !isEmpty && !isPreFilled ? () => _clearCard(index) : null,
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: isPreFilled
              ? Color(0xFF1B3A2A)
              : isEmpty
                  ? Color(0xFF1B1E24)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Color(0xFF89F1EC)
                : isPreFilled
                    ? Color(0xFF2A5A3A)
                    : isEmpty
                        ? Color(0xFF35373C)
                        : Colors.grey[400]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4E5054),
                  ),
                ),
              )
            : Stack(
                children: [
                  Center(
                    child: Text(
                      card,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isIncomplete
                            ? Colors.grey
                            : isPreFilled
                                ? _getPrefilledCardColor(card)
                                : _getCardColor(card),
                      ),
                    ),
                  ),
                  if (!isIncomplete && !isPreFilled)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(0xFF35373C),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white70, size: 10),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildCardGridSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF02050B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF1B1E24), width: 1),
      ),
      child: Column(
        children: [
          _buildRankRow(_ranks.sublist(0, 5)),
          if (_selectedRank != null && _selectedRankRow == 0) ...[
            SizedBox(height: 6),
            _buildSuitSelectionRow(),
          ],
          SizedBox(height: 6),
          _buildRankRow(_ranks.sublist(5, 10)),
          if (_selectedRank != null && _selectedRankRow == 1) ...[
            SizedBox(height: 6),
            _buildSuitSelectionRow(),
          ],
          SizedBox(height: 6),
          _buildCenteredRankRow(_ranks.sublist(10, 13)),
          if (_selectedRank != null && _selectedRankRow == 2) ...[
            SizedBox(height: 6),
            _buildSuitSelectionRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildRankRow(List<String> ranks) {
    return Row(
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
      children: [
        Expanded(child: Container()),
        ...ranks.map((rank) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: _buildRankCard(rank),
            ),
          );
        }).toList(),
        Expanded(child: Container()),
      ],
    );
  }

  Widget _buildRankCard(String rank) {
    final excluded = _allExcluded;
    bool isCompletelyExcluded = _suits.every((suit) => excluded.contains('$rank$suit'));
    bool isSelected = _selectedRank == rank;

    return GestureDetector(
      onTap: isCompletelyExcluded ? null : () => _selectRank(rank),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF89F1EC).withValues(alpha: 0.15)
              : isCompletelyExcluded
                  ? Color(0xFF0A0A0E)
                  : Color(0xFF1B1E24),
          border: Border.all(
            color: isSelected
                ? Color(0xFF89F1EC)
                : isCompletelyExcluded
                    ? Color(0xFF1B1E24)
                    : Color(0xFF35373C),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            rank,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Color(0xFF89F1EC)
                  : isCompletelyExcluded
                      ? Color(0xFF35373C)
                      : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuitSelectionRow() {
    return Row(
      children: _suits.map((suit) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: _buildSuitCard(suit),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuitCard(String suit) {
    String card = '$_selectedRank$suit';
    bool isExcluded = _allExcluded.contains(card);
    Color suitColor = _getSuitColor(suit);

    return GestureDetector(
      onTap: isExcluded ? null : () => _selectSuit(suit),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isExcluded ? Color(0xFF0A0A0E) : Color(0xFF1B1E24),
          border: Border.all(
            color: isExcluded ? Color(0xFF1B1E24) : Color(0xFF35373C),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _selectedRank!,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isExcluded ? Color(0xFF35373C) : suitColor,
              ),
            ),
            Text(
              suit,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isExcluded ? Color(0xFF35373C) : suitColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Save button — full width mint pill
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _canSave() ? () => _saveCards() : null,
            style: TextButton.styleFrom(
              backgroundColor: _canSave() ? Color(0xFF89F1EC) : Color(0xFF1B1E24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.ibmPlexSans(
                color: _canSave() ? Colors.black : Color(0xFF4E5054),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        // Cancel button — outline pill
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _selectRank(String rank) {
    setState(() {
      _selectedRank = rank;

      int rankIndex = _ranks.indexOf(rank);
      if (rankIndex < 5) {
        _selectedRankRow = 0;
      } else if (rankIndex < 10) {
        _selectedRankRow = 1;
      } else {
        _selectedRankRow = 2;
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
      if (_targetSlotIndex! < _selectedCards.length) {
        if (_selectedCards[_targetSlotIndex!].length > 1) {
          _currentlySelected.remove(_selectedCards[_targetSlotIndex!]);
        }
        _selectedCards[_targetSlotIndex!] = card;
        _currentlySelected.add(card);
      }

      _selectedRank = null;
      _selectedRankRow = null;
      _targetSlotIndex = null;
    });
  }

  bool _isSlotPreFilled(int index) {
    if (widget.existingBoardCards == null) return false;

    if (index < 3) {
      return widget.existingBoardCards!.flop.length > index &&
             widget.existingBoardCards!.flop[index].isNotEmpty;
    } else if (index == 3) {
      return widget.existingBoardCards!.turn?.isNotEmpty == true;
    } else if (index == 4) {
      return widget.existingBoardCards!.river?.isNotEmpty == true;
    }
    return false;
  }

  void _clearCard(int index) {
    if (_isSlotPreFilled(index)) return;

    setState(() {
      if (_selectedCards[index].length > 1) {
        _currentlySelected.remove(_selectedCards[index]);
      }
      _selectedCards[index] = '';

      if (_targetSlotIndex == index) {
        _selectedRank = null;
        _targetSlotIndex = null;
      }
    });
  }

  Color _getCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Color(0xFFE85D5D);
    }
    return Color(0xFF2D2D2D);
  }

  Color _getPrefilledCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Color(0xFFE85D5D);
    }
    return Colors.white;
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Color(0xFFE85D5D);
    }
    return Colors.white;
  }

  bool _canSave() {
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
