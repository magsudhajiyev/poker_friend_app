import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import 'easy_logging/board_add_later_bar.dart';
import '../design_system/components/pickers/card_keyboard.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class AllInBoardCardsDialog extends StatefulWidget {
  final List<String> excludedCards; // Hole cards to exclude from selection
  final BoardCards? existingBoardCards; // Already selected board cards

  /// Easy logging: offer "Add later" and auto-confirm on the last card.
  final bool allowAddLater;
  final bool autoConfirm;

  const AllInBoardCardsDialog({
    Key? key,
    this.excludedCards = const [],
    this.existingBoardCards,
    this.allowAddLater = false,
    this.autoConfirm = false,
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
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.allInBoardTitle,
      showCloseButton: false,
      padding: const EdgeInsets.all(20),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              backgroundColor: valid ? AppColors.accentPrimary : AppColors.neutral800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              l10n.commonSave,
              style: AppTypography.ibm(
                color: valid ? Colors.black : AppColors.infoCardDateText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        if (widget.allowAddLater) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(context, const BoardAddLater()),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                l10n.easyLogBoardAddLater,
                style: AppTypography.ibm(
                  color: AppColors.accentPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
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
              l10n.commonCancel,
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

  bool _autoSaved = false;

  void _onCardCommitted(int slotIndex, String card) {
    setState(() {
      _slots[slotIndex] = card;
      _currentlySelected.add(card);
    });
    if (widget.autoConfirm && _canSave() && !_autoSaved) {
      _autoSaved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveCards();
      });
    }
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
