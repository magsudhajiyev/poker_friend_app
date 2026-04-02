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

  // All excluded cards: hero hole cards + already selected board cards
  Set<String> get _allExcluded {
    final excluded = <String>{};
    excluded.addAll(widget.excludedCards);
    excluded.addAll(widget.usedCards);
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
            '${_getStreetName()} ${widget.currentRound == BettingRound.flop ? 'Cards' : 'Card'}',
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
    String label = widget.currentRound == BettingRound.flop
        ? 'Select 3 Flop Cards:'
        : widget.currentRound == BettingRound.turn
            ? 'Select Turn Card:'
            : 'Select River Card:';

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
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
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
                ..._buildExistingFlopCards(),
                SizedBox(width: 6),
                _buildTurnSlot(),
              ] else if (widget.currentRound == BettingRound.river) ...[
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
    final cards = _flop.where((c) => c.isNotEmpty && c.length > 1).toList();
    final widgets = <Widget>[];
    for (int i = 0; i < cards.length; i++) {
      if (i > 0) widgets.add(SizedBox(width: 6));
      widgets.add(Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[400]!, width: 1),
        ),
        child: Center(
          child: Text(
            cards[i],
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getCardColor(cards[i]),
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildExistingTurnCard() {
    if (_turn == null || _turn!.isEmpty || _turn!.length <= 1) {
      return SizedBox.shrink();
    }
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Center(
        child: Text(
          _turn!,
          style: GoogleFonts.ibmPlexSans(
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
    final isActive = _targetSlotIndex == index;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearCard(index) : null,
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: isEmpty ? Color(0xFF1B1E24) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Color(0xFF89F1EC)
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
                        color: isIncomplete ? Colors.grey : _getCardColor(card),
                      ),
                    ),
                  ),
                  if (!isIncomplete)
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

  Widget _buildTurnSlot() {
    final card = _turn ?? '';
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;
    final isActive = _targetSlotIndex == 3;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearTurn() : null,
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: isEmpty ? Color(0xFF1B1E24) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Color(0xFF89F1EC)
                : isEmpty
                    ? Color(0xFF35373C)
                    : Colors.grey[400]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '?',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 22,
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
                        color: isIncomplete ? Colors.grey : _getCardColor(card),
                      ),
                    ),
                  ),
                  if (!isIncomplete)
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

  Widget _buildRiverSlot() {
    final card = _river ?? '';
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;
    final isActive = _targetSlotIndex == 4;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearRiver() : null,
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: isEmpty ? Color(0xFF1B1E24) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Color(0xFF89F1EC)
                : isEmpty
                    ? Color(0xFF35373C)
                    : Colors.grey[400]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '?',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 22,
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
                        color: isIncomplete ? Colors.grey : _getCardColor(card),
                      ),
                    ),
                  ),
                  if (!isIncomplete)
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
            onPressed: _isValid() ? () => _saveCards() : null,
            style: TextButton.styleFrom(
              backgroundColor: _isValid() ? Color(0xFF89F1EC) : Color(0xFF1B1E24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.ibmPlexSans(
                color: _isValid() ? Colors.black : Color(0xFF4E5054),
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

  // For cards on white background (filled slots)
  Color _getCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) {
      return Color(0xFFE85D5D);
    }
    return Color(0xFF2D2D2D);
  }

  // For cards on dark background (existing flop/turn display)
  Color _getExistingCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
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
