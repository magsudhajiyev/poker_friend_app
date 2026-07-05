import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import 'card_keyboard.dart';
import '../design_system/constants/colors.dart';

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
  late List<String> _slots; // All 5 board cards
  Set<String> _currentlySelected = {};
  late Set<int> _lockedSlots;

  @override
  void initState() {
    super.initState();
    _slots = ['', '', '', '', ''];
    _lockedSlots = {};

    if (widget.existingBoardCards != null) {
      final board = widget.existingBoardCards!;
      for (int i = 0; i < board.flop.length && i < 3; i++) {
        if (board.flop[i].isNotEmpty) {
          _slots[i] = board.flop[i];
          _currentlySelected.add(board.flop[i]);
          _lockedSlots.add(i);
        }
      }
      if (board.turn != null && board.turn!.isNotEmpty) {
        _slots[3] = board.turn!;
        _currentlySelected.add(board.turn!);
        _lockedSlots.add(3);
      }
      if (board.river != null && board.river!.isNotEmpty) {
        _slots[4] = board.river!;
        _currentlySelected.add(board.river!);
        _lockedSlots.add(4);
      }
    }
  }

  Set<String> get _allExcluded => {
    ...widget.excludedCards,
    ..._currentlySelected,
  };

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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral800, width: 1),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                CardKeyboard(
                  slotCount: 5,
                  slots: _slots,
                  excludedCards: _allExcluded,
                  onCardCommitted: _onCardCommitted,
                  onCardCleared: _onCardCleared,
                  lockedSlotIndices: _lockedSlots,
                ),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SvgPicture.asset(
          'icons/figma_icons/Capa_1.svg',
          width: 22,
          height: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.allInBoardTitle,
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

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context);
    final valid = _canSave();
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: valid ? _saveCards : null,
            style: TextButton.styleFrom(
              backgroundColor: valid ? AppColors.buttonPrimary : AppColors.neutral800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.commonSave,
              style: GoogleFonts.ibmPlexSans(
                color: valid ? Colors.black : AppColors.infoCardDateText,
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
              l10n.commonCancel,
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

  bool _canSave() {
    return _slots.every((card) =>
        card.isNotEmpty && card.length > 1 &&
        (card.contains('♠') || card.contains('♥') || card.contains('♦') || card.contains('♣')));
  }

  void _saveCards() {
    final boardCards = BoardCards(
      flop: _slots.sublist(0, 3),
      turn: _slots[3],
      river: _slots[4],
    );
    Navigator.pop(context, boardCards);
  }
}
