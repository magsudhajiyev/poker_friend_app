import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hand_state_machine.dart';


class HandReviewDialog extends StatefulWidget {
  final HoleCards? existingCards;
  final Set<String> usedCards; // Board cards to exclude from selection
  final bool existingIsStarred;
  final List<String> existingTags;
  final String? existingNotes;

  const HandReviewDialog({
    Key? key,
    this.existingCards,
    this.usedCards = const {},
    this.existingIsStarred = false,
    this.existingTags = const [],
    this.existingNotes,
  }) : super(key: key);

  @override
  _HandReviewDialogState createState() => _HandReviewDialogState();
}

class _HandReviewDialogState extends State<HandReviewDialog> {
  // Card selection state
  late String? _card1;
  late String? _card2;
  Set<String> _currentlySelected = {};
  String? _selectedRank;
  int? _selectedRankRow;
  int? _targetSlotIndex;

  // Annotation state
  late bool _isStarred;
  late List<String> _selectedTags;
  late TextEditingController _notesController;

  final List<String> _suits = ['♠', '♥', '♦', '♣'];
  final List<String> _ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'];

  // Predefined tags
  final List<Map<String, dynamic>> _availableTags = [
    {'label': 'Bluff', 'icon': Icons.psychology},
    {'label': 'Value', 'icon': Icons.attach_money},
    {'label': 'Mistake', 'icon': Icons.error_outline},
    {'label': 'Cooler', 'icon': Icons.ac_unit},
    {'label': 'Hero Call', 'icon': Icons.shield},
    {'label': 'Exploit', 'icon': Icons.gps_fixed},
  ];

  @override
  void initState() {
    super.initState();
    _card1 = widget.existingCards?.card1;
    _card2 = widget.existingCards?.card2;
    _isStarred = widget.existingIsStarred;
    _selectedTags = List<String>.from(widget.existingTags);
    _notesController = TextEditingController(text: widget.existingNotes ?? '');

    // Add existing selections to currently selected
    if (_card1?.isNotEmpty == true) _currentlySelected.add(_card1!);
    if (_card2?.isNotEmpty == true) _currentlySelected.add(_card2!);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHoleCardsSection(),
                    SizedBox(height: 16),
                    _buildTagsSection(),
                    SizedBox(height: 16),
                    _buildNotesSection(),
                    SizedBox(height: 24),
                    _buildActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hand Review',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Star button
          GestureDetector(
            onTap: () => setState(() => _isStarred = !_isStarred),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isStarred
                    ? Colors.amber.withValues(alpha: 0.2)
                    : Color(0xFF1B1E24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isStarred ? Colors.amber : Color(0xFF35373C),
                  width: 1,
                ),
              ),
              child: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred ? Colors.amber : Color(0xFF8C8C8C),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsSection() {
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
          Row(
            children: [
              Text(
                'Your Hole Cards',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '(optional)',
                style: GoogleFonts.ibmPlexSans(
                  color: Color(0xFF8C8C8C),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Card slots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSelectedCardSlot(0),
              SizedBox(width: 12),
              _buildSelectedCardSlot(1),
            ],
          ),
          SizedBox(height: 14),
          // Rank selection
          _buildRankAndSuitSelection(),
        ],
      ),
    );
  }

  Widget _buildSelectedCardSlot(int index) {
    final card = index == 0 ? (_card1 ?? '') : (_card2 ?? '');
    final isEmpty = card.isEmpty;
    final isIncomplete = card.length == 1;
    final isActive = _targetSlotIndex == index;

    return GestureDetector(
      onTap: !isEmpty ? () => _clearCard(index) : null,
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: isEmpty
              ? Color(0xFF1B1E24)
              : Colors.white,
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
                    color: Color(0xFF4E5054),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Stack(
                children: [
                  Center(
                    child: Text(
                      card,
                      style: GoogleFonts.ibmPlexSans(
                        color: isIncomplete ? Colors.grey : _getCardColor(card),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
                        child: Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildRankAndSuitSelection() {
    return Column(
      children: [
        // Row 1: A, K, Q, J, T
        Row(
          children: _ranks.sublist(0, 5).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
        ),
        if (_selectedRank != null && _selectedRankRow == 0) ...[
          SizedBox(height: 6),
          _buildSuitSelection(),
        ],
        SizedBox(height: 6),
        // Row 2: 9, 8, 7, 6, 5
        Row(
          children: _ranks.sublist(5, 10).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
        ),
        if (_selectedRank != null && _selectedRankRow == 1) ...[
          SizedBox(height: 6),
          _buildSuitSelection(),
        ],
        SizedBox(height: 6),
        // Row 3: 4, 3, 2 (centered)
        Row(
          children: [
            Expanded(child: Container()),
            ..._ranks.sublist(10, 13).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
            Expanded(child: Container()),
          ],
        ),
        if (_selectedRank != null && _selectedRankRow == 2) ...[
          SizedBox(height: 6),
          _buildSuitSelection(),
        ],
      ],
    );
  }

  Widget _buildRankCard(String rank) {
    bool isCompletelyExcluded = _suits.every((suit) =>
        widget.usedCards.contains('$rank$suit') ||
        _currentlySelected.contains('$rank$suit'));
    bool isSelected = _selectedRank == rank;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
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
      ),
    );
  }

  Widget _buildSuitSelection() {
    return Row(
      children: _suits.map((suit) => Expanded(child: _buildSuitCard(suit))).toList(),
    );
  }

  Widget _buildSuitCard(String suit) {
    String card = '$_selectedRank$suit';
    bool isExcluded = widget.usedCards.contains(card) || _currentlySelected.contains(card);
    Color suitColor = _getSuitColor(suit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
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
          child: Center(
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
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Tags',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) => _buildTagChip(tag['label'], tag['icon'])).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(String label, IconData icon) {
    final isSelected = _selectedTags.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTags.remove(label);
          } else {
            _selectedTags.add(label);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF89F1EC).withValues(alpha: 0.15)
              : Color(0xFF1B1E24),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected ? Color(0xFF89F1EC) : Color(0xFF35373C),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Color(0xFF89F1EC) : Color(0xFF8C8C8C),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: isSelected ? Color(0xFF89F1EC) : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF02050B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFF1B1E24)),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 2,
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a note about this hand...',
              hintStyle: GoogleFonts.ibmPlexSans(
                color: Color(0xFF4E5054),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Save Hand button - full width mint pill
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => _saveHand(),
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFF89F1EC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Save Hand',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        // Skip button - outline pill
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => _skip(),
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
              'Skip',
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

      if (_card1 == null || _card1!.isEmpty) {
        _targetSlotIndex = 0;
        _card1 = rank;
      } else if (_card2 == null || _card2!.isEmpty) {
        _targetSlotIndex = 1;
        _card2 = rank;
      }
    });
  }

  void _selectSuit(String suit) {
    if (_selectedRank == null || _targetSlotIndex == null) return;

    String card = '$_selectedRank$suit';

    if (_currentlySelected.length >= 2 && !_currentlySelected.contains(_card1) && !_currentlySelected.contains(_card2)) {
      return;
    }

    setState(() {
      if (_targetSlotIndex == 0) {
        if (_card1 != null && _card1!.length > 1) {
          _currentlySelected.remove(_card1);
        }
        _card1 = card;
        _currentlySelected.add(card);
      } else if (_targetSlotIndex == 1) {
        if (_card2 != null && _card2!.length > 1) {
          _currentlySelected.remove(_card2);
        }
        _card2 = card;
        _currentlySelected.add(card);
      }

      _selectedRank = null;
      _selectedRankRow = null;
      _targetSlotIndex = null;
    });
  }

  void _clearCard(int index) {
    setState(() {
      if (index == 0) {
        if (_card1 != null && _card1!.length > 1) {
          _currentlySelected.remove(_card1);
        }
        _card1 = '';
      } else {
        if (_card2 != null && _card2!.length > 1) {
          _currentlySelected.remove(_card2);
        }
        _card2 = '';
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

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Color(0xFFE85D5D);
    }
    return Colors.white;
  }

  bool _isCompleteCard(String? card) {
    return card != null && card.isNotEmpty && card.length > 1 &&
           (card.contains('♠') || card.contains('♥') || card.contains('♦') || card.contains('♣'));
  }

  void _skip() {
    // Return with no cards but include annotations if any were made
    Navigator.pop(context, {
      'holeCards': null,
      'isStarred': _isStarred,
      'tags': _selectedTags,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
    });
  }

  void _saveHand() {
    final card1Complete = _isCompleteCard(_card1);
    final card2Complete = _isCompleteCard(_card2);

    HoleCards? holeCards;

    if (card1Complete && card2Complete) {
      if (_card1 == _card2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You cannot select the same card twice!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      holeCards = HoleCards(card1: _card1, card2: _card2);
    } else if (card1Complete || card2Complete) {
      // One card selected but not both
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select both hole cards or leave both empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'holeCards': holeCards,
      'isStarred': _isStarred,
      'tags': _selectedTags,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
    });
  }
}
