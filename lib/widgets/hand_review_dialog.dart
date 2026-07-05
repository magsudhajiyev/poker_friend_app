import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import 'card_keyboard.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

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
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(color: AppColors.neutral800, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _buildHoleCardsSection(),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTagsSection(),
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
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
                color: AppColors.neutral700,
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
                l10n.handReviewTitle,
                style: AppTypography.ibm(
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
                    : AppColors.neutral800,
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
                border: Border.all(
                  color: _isStarred ? Colors.amber : AppColors.neutral700,
                  width: 1,
                ),
              ),
              child: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred ? Colors.amber : AppColors.textDisabled,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCardsSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.handReviewYourHoleCards,
              style: AppTypography.ibm(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.handReviewOptional,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.handReviewQuickTags,
          style: AppTypography.ibm(
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
              ? AppColors.buttonPrimary.withValues(alpha: 0.15)
              : AppColors.neutral800,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          border: Border.all(
            color: isSelected ? AppColors.buttonPrimary : AppColors.neutral700,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.buttonPrimary : AppColors.textDisabled,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.ibm(
                fontSize: 13,
                color: isSelected ? AppColors.buttonPrimary : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.handReviewNotes,
          style: AppTypography.ibm(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppDecorations.radius14),
            border: Border.all(color: AppColors.neutral800),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 2,
            style: AppTypography.ibm(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.handReviewNotesHint,
              hintStyle: AppTypography.ibm(
                color: AppColors.infoCardDateText,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _saveHand,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.handReviewSaveHand,
              style: AppTypography.ibm(
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
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.handReviewSkip,
              style: AppTypography.ibm(
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.handReviewDuplicateCardError), backgroundColor: Colors.red),
        );
        return;
      }
      holeCards = HoleCards(card1: _slots[0], card2: _slots[1]);
    } else if (c1 || c2) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.handReviewSelectBothOrNone),
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
