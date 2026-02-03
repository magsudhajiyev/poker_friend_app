import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/hand_state_machine.dart';
import '../design_system/design_system.dart';

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400, maxHeight: 750),
            decoration: BoxDecoration(
              color: AppColors.glassyCardColor(),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.whiteBorder(),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with Star
                  _buildHeader(),
                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hole Cards Section
                        _buildHoleCardsSection(),
                        SizedBox(height: 16),
                        // Tags Section
                        _buildTagsSection(),
                        SizedBox(height: 16),
                        // Notes Section
                        _buildNotesSection(),
                        SizedBox(height: 20),
                        // Actions
                        _buildActions(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
              Icons.rate_review,
              color: AppColors.accentGreen,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Hand Review',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          // Star button
          GestureDetector(
            onTap: () => setState(() => _isStarred = !_isStarred),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isStarred ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred ? Colors.amber : Colors.white54,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.whiteBorder()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Color(0xFFFFD700),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'YOUR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Hole Cards',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '(optional)',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Card slots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSelectedCardSlot(0),
              SizedBox(width: 16),
              _buildSelectedCardSlot(1),
            ],
          ),
          SizedBox(height: 12),
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

    return GestureDetector(
      onTap: !isEmpty ? () => _clearCard(index) : null,
      child: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: isEmpty ? Colors.black.withOpacity(0.3) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? AppColors.whiteBorder() : Colors.grey[300]!,
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
    return Column(
      children: [
        // Row 1: A, K, Q, J, T
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _ranks.sublist(0, 5).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
        ),
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
        if (_selectedRank != null && _selectedRankRow == 1) ...[
          SizedBox(height: 8),
          _buildSuitSelection(),
        ],
        SizedBox(height: 8),
        // Row 3: 4, 3, 2 (centered)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: Container()),
            ..._ranks.sublist(10, 13).map((rank) => Expanded(child: _buildRankCard(rank))).toList(),
            Expanded(child: Container()),
          ],
        ),
        if (_selectedRank != null && _selectedRankRow == 2) ...[
          SizedBox(height: 8),
          _buildSuitSelection(),
        ],
      ],
    );
  }

  Widget _buildRankCard(String rank) {
    bool isCompletelyExcluded = _suits.every((suit) =>
        widget.usedCards.contains('$rank$suit') ||
        _currentlySelected.contains('$rank$suit'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isCompletelyExcluded ? null : () => _selectRank(rank),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isCompletelyExcluded ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.3),
            border: Border.all(
              color: isCompletelyExcluded ? Colors.grey[700]! : AppColors.whiteBorder(),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              rank,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCompletelyExcluded ? Colors.grey[600] : Colors.white,
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
    bool isExcluded = widget.usedCards.contains(card) || _currentlySelected.contains(card);
    Color suitColor = _getSuitColor(suit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isExcluded ? null : () => _selectSuit(suit),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isExcluded ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.3),
            border: Border.all(
              color: isExcluded ? Colors.grey[700]! : AppColors.whiteBorder(),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isExcluded ? Colors.grey[600] : suitColor,
                  ),
                ),
                Text(
                  suit,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isExcluded ? Colors.grey[600] : suitColor,
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 8),
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
          color: isSelected ? Color(0xFFBAFF9A).withOpacity(0.2) : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFFBAFF9A) : AppColors.whiteBorder(),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Color(0xFFBAFF9A) : Colors.white54,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Color(0xFFBAFF9A) : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
          'Notes (optional)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.whiteBorder()),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 2,
            style: TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a note about this hand...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
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
              onPressed: () => _skip(),
              child: Text(
                'Skip',
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
              color: Color(0xFFBAFF9A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () => _saveHand(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Save Hand',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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
      return Colors.red[300]!;
    }
    return Color(0xFFE0E0E0);
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') {
      return Colors.red[300]!;
    }
    return Color(0xFFE0E0E0);
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
