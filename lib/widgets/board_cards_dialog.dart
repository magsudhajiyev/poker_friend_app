import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';

class BoardCardsDialog extends StatefulWidget {
  final BettingRound currentRound;
  final BoardCards? existingCards;
  final List<String> excludedCards;
  final Set<String> usedCards;

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
  String? _selectedRank;
  int? _selectedRankRow;
  int? _targetSlotIndex;

  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  @override
  void initState() {
    super.initState();
    _flop = widget.existingCards?.flop.toList() ?? ['', '', ''];
    _turn = widget.existingCards?.turn;
    _river = widget.existingCards?.river;

    _currentlySelected.addAll(_flop.where((card) => card.isNotEmpty));
    if (_turn?.isNotEmpty == true) _currentlySelected.add(_turn!);
    if (_river?.isNotEmpty == true) _currentlySelected.add(_river!);
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
              '${_getStreetName()} Cards',
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
    int cardCount = widget.currentRound == BettingRound.flop ? 3 : 1;
    String label = widget.currentRound == BettingRound.flop
        ? 'Select 3 Flop Cards:'
        : widget.currentRound == BettingRound.turn
            ? 'Select Turn Card:'
            : 'Select River Card:';

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
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.currentRound == BettingRound.flop) ...[
                _buildCardSlot(0),
                SizedBox(width: 8),
                _buildCardSlot(1),
                SizedBox(width: 8),
                _buildCardSlot(2),
              ] else if (widget.currentRound == BettingRound.turn) ...[
                // Show existing flop cards
                ..._buildExistingFlopCards(),
                SizedBox(width: 6),
                _buildTurnSlot(),
              ] else if (widget.currentRound == BettingRound.river) ...[
                // Show existing flop and turn cards (smaller to fit all 5)
                ..._buildExistingFlopCards(),
                SizedBox(width: 6),
                _buildExistingTurnCard(),
                SizedBox(width: 6),
                _buildRiverSlot(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExistingFlopCards() {
    return _flop.where((c) => c.isNotEmpty && c.length > 1).map((card) {
      return Container(
        width: 48,
        height: 62,
        decoration: BoxDecoration(
          color: Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            card,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getCardColor(card),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildExistingTurnCard() {
    if (_turn == null || _turn!.isEmpty || _turn!.length <= 1) {
      return SizedBox.shrink();
    }
    return Container(
      width: 48,
      height: 62,
      decoration: BoxDecoration(
        color: Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _turn!,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _getCardColor(_turn!),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSlot(int index) {
    final card = _flop[index];
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearCard(index) : null,
      child: Container(
        width: 48,
        height: 62,
        decoration: BoxDecoration(
          color: Color(0xFF2B2B2B),
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

  Widget _buildTurnSlot() {
    final card = _turn ?? '';
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearTurn() : null,
      child: Container(
        width: 48,
        height: 62,
        decoration: BoxDecoration(
          color: Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isEmpty
              ? Text(
                  '?',
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

  Widget _buildRiverSlot() {
    final card = _river ?? '';
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearRiver() : null,
      child: Container(
        width: 48,
        height: 62,
        decoration: BoxDecoration(
          color: Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isEmpty
              ? Text(
                  '?',
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
                     widget.usedCards.contains(card) ||
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
              onTap: _isValid() ? () => _saveCards() : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isValid() ? Color(0xFF62E3BC) : Colors.grey[700],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _isValid() ? Colors.black : Colors.white.withOpacity(0.5),
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

      int rankIndex = _ranks.indexOf(rank);
      if (rankIndex < 5) {
        _selectedRankRow = 0;
      } else if (rankIndex < 10) {
        _selectedRankRow = 1;
      } else {
        _selectedRankRow = 2;
      }

      if (widget.currentRound == BettingRound.flop) {
        for (int i = 0; i < 3; i++) {
          if (_flop[i].isEmpty) {
            _targetSlotIndex = i;
            _flop[i] = rank;
            break;
          }
        }
      } else if (widget.currentRound == BettingRound.turn) {
        _targetSlotIndex = 3;
        _turn = rank;
      } else if (widget.currentRound == BettingRound.river) {
        _targetSlotIndex = 4;
        _river = rank;
      }
    });
  }

  void _selectSuit(String suit) {
    if (_selectedRank == null || _targetSlotIndex == null) return;

    String card = '$_selectedRank$suit';

    setState(() {
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

      _selectedRank = null;
      _selectedRankRow = null;
      _targetSlotIndex = null;
    });
  }

  void _clearCard(int index) {
    setState(() {
      final card = _flop[index];
      if (card.isNotEmpty && card.length > 1) {
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
      return _flop.every((card) => card.isNotEmpty && card.length > 1);
    } else if (widget.currentRound == BettingRound.turn) {
      return _turn != null && _turn!.isNotEmpty && _turn!.length > 1;
    } else if (widget.currentRound == BettingRound.river) {
      return _river != null && _river!.isNotEmpty && _river!.length > 1;
    }
    return false;
  }

  void _saveCards() {
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
