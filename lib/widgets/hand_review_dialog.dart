import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hand_state_machine.dart';
import 'card_keyboard.dart';

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
  late List<String> _slots;
  Set<String> _currentlySelected = {};

  // Annotation state
  late bool _isStarred;
  late List<String> _selectedTags;
  late TextEditingController _notesController;

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
    final c1 = widget.existingCards?.card1 ?? '';
    final c2 = widget.existingCards?.card2 ?? '';
    _slots = [c1, c2];
    if (c1.isNotEmpty && c1.length > 1) _currentlySelected.add(c1);
    if (c2.isNotEmpty && c2.length > 1) _currentlySelected.add(c2);

    _isStarred = widget.existingIsStarred;
    _selectedTags = List<String>.from(widget.existingTags);
    _notesController = TextEditingController(text: widget.existingNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Set<String> get _allExcluded => {...widget.usedCards, ..._currentlySelected};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1B1E24), width: 1),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHoleCardsSection(),
                    const SizedBox(height: 16),
                    _buildTagsSection(),
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context, {'goBack': true}),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF35373C),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Hand Review',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isStarred = !_isStarred),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isStarred
                    ? Colors.amber.withValues(alpha: 0.2)
                    : const Color(0xFF1B1E24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isStarred ? Colors.amber : const Color(0xFF35373C),
                  width: 1,
                ),
              ),
              child: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred ? Colors.amber : const Color(0xFF8C8C8C),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsSection() {
    return Column(
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
            const SizedBox(width: 6),
            Text(
              '(optional)',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CardKeyboard(
          slotCount: 2,
          slots: _slots,
          excludedCards: _allExcluded,
          onCardCommitted: _onCardCommitted,
          onCardCleared: _onCardCleared,
        ),
      ],
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
        const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF89F1EC).withValues(alpha: 0.15)
              : const Color(0xFF1B1E24),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected ? const Color(0xFF89F1EC) : const Color(0xFF35373C),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF89F1EC) : const Color(0xFF8C8C8C),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: isSelected ? const Color(0xFF89F1EC) : Colors.white70,
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
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF02050B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1B1E24)),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 2,
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a note about this hand...',
              hintStyle: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF4E5054),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _saveHand,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF89F1EC),
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
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _skip,
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

  void _onCardCommitted(int slotIndex, String card) {
    setState(() {
      _slots[slotIndex] = card;
      _currentlySelected.add(card);
    });
  }

  void _onCardCleared(int slotIndex) {
    setState(() {
      final old = _slots[slotIndex];
      if (old.isNotEmpty && old.length > 1) _currentlySelected.remove(old);
      _slots[slotIndex] = '';
    });
  }

  bool _isCompleteCard(String card) {
    return card.isNotEmpty && card.length > 1 &&
           (card.contains('♠') || card.contains('♥') || card.contains('♦') || card.contains('♣'));
  }

  void _skip() {
    Navigator.pop(context, {
      'holeCards': null,
      'isStarred': _isStarred,
      'tags': _selectedTags,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
    });
  }

  void _saveHand() {
    final c1 = _isCompleteCard(_slots[0]);
    final c2 = _isCompleteCard(_slots[1]);

    HoleCards? holeCards;

    if (c1 && c2) {
      if (_slots[0] == _slots[1]) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot select the same card twice!'), backgroundColor: Colors.red),
        );
        return;
      }
      holeCards = HoleCards(card1: _slots[0], card2: _slots[1]);
    } else if (c1 || c2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
