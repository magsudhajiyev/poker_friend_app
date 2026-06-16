import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../models/poker_game_state.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import '../utils/poker_positions.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import 'seat_config_sheet.dart';

class TableManagementSheet extends StatefulWidget {
  final PokerGameState gameState;
  final PokerSessionManager sessionManager;
  final int heroSeat;
  final VoidCallback onChanged;

  const TableManagementSheet({
    super.key,
    required this.gameState,
    required this.sessionManager,
    required this.heroSeat,
    required this.onChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required PokerGameState gameState,
    required PokerSessionManager sessionManager,
    required int heroSeat,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TableManagementModal(
        gameState: gameState,
        sessionManager: sessionManager,
        heroSeat: heroSeat,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<TableManagementSheet> createState() => _TableManagementSheetState();
}

class _TableManagementSheetState extends State<TableManagementSheet> {
  @override
  Widget build(BuildContext context) {
    return _TableManagementModal(
      gameState: widget.gameState,
      sessionManager: widget.sessionManager,
      heroSeat: widget.heroSeat,
      onChanged: widget.onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Main modal widget
// ---------------------------------------------------------------------------

class _TableManagementModal extends StatefulWidget {
  final PokerGameState gameState;
  final PokerSessionManager sessionManager;
  final int heroSeat;
  final VoidCallback onChanged;

  const _TableManagementModal({
    required this.gameState,
    required this.sessionManager,
    required this.heroSeat,
    required this.onChanged,
  });

  @override
  State<_TableManagementModal> createState() => _TableManagementModalState();
}

class _TableManagementModalState extends State<_TableManagementModal> {
  int get _heroSeat => widget.sessionManager.ourSeatNumber ?? widget.heroSeat;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _sessionElapsed() {
    final start = widget.sessionManager.sessionStartTime;
    if (start == null) return '';
    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  String _getPositionForSeat(int seat) {
    final btnPos = widget.gameState.buttonPosition;
    final activeSeatsList = widget.sessionManager.activeSeats.toList()..sort();
    final activeCount = activeSeatsList.length;

    if (seat == btnPos) return 'BTN';
    if (seat == widget.sessionManager.actualBBSeat) return 'BB';
    if (seat == widget.sessionManager.actualSBSeat) return 'SB';
    if (activeCount <= 3) return '';

    return PokerPositions.getPositionNameForActivePlayers(seat, btnPos, activeSeatsList);
  }

  void _cycleButton() {
    final active = widget.sessionManager.activeSeats.toList()..sort();
    if (active.isEmpty) return;
    final current = widget.gameState.buttonPosition;
    final idx = active.indexOf(current);
    final next = active[(idx + 1) % active.length];
    setState(() {
      widget.gameState.buttonPosition = next;
      widget.sessionManager.buttonPosition = next;
      widget.sessionManager.actualSBSeat = widget.gameState.effectiveSBPosition;
      widget.sessionManager.actualBBSeat = widget.gameState.effectiveBBPosition;
    });
    widget.onChanged();
  }

  /// Opens SeatConfigSheet for any seat (add or edit).
  void _openSeatConfig(int seat) {
    final isActive = widget.sessionManager.activeSeats.contains(seat);
    final isHero = seat == _heroSeat;

    final defaultStack = widget.sessionManager.bigBlind > 0
        ? (widget.sessionManager.bigBlind * 100).toDouble()
        : 0.0;
    final heroName = widget.sessionManager.playerNames[_heroSeat] ?? '';

    final seatedPlayers = <String, int>{};
    for (final entry in widget.sessionManager.playerNames.entries) {
      if (widget.sessionManager.activeSeats.contains(entry.key)) {
        seatedPlayers[entry.value.toLowerCase()] = entry.key;
      }
    }

    final currentName = widget.sessionManager.playerNames[seat] ?? '';
    final currentStack =
        isActive ? widget.gameState.getPlayerStack(seat) : defaultStack;

    final l10n = AppLocalizations.of(context);
    SeatConfigSheet.show(
      context: context,
      seatNumber: seat,
      initialName: isHero ? heroName : currentName,
      initialStack: currentStack,
      isHero: isHero,
      isActive: isActive,
      defaultStack: defaultStack,
      heroName: heroName,
      seatedPlayers: seatedPlayers,
      isCash: widget.sessionManager.gameType == GameType.cash,
      showSaveAsOpponent: !isHero,
      titleOverride: l10n.tableManagementAddPlayerSeatTitle(seat),
      onSave: ({
        required String name,
        required double stack,
        required bool isHero,
        required bool isActive,
      }) {
        if (!isActive) {
          // Remove player
          widget.sessionManager.activeSeats.remove(seat);
          widget.sessionManager.playerNames.remove(seat);
          widget.sessionManager.playerStacks.remove(seat);
          widget.sessionManager.playerIds.remove(seat);
          widget.gameState.setPlayerActive(seat, false);
          widget.onChanged();
          setState(() {});
          // Defer so any dialog appears after SeatConfigSheet dismisses
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _checkButtonOnEmptySeat();
          });
          return;
        }

        if (isHero && widget.sessionManager.ourSeatNumber != seat) {
          // Hero moving to a different seat — carry over current stack
          final heroStack = widget.gameState.getPlayerStack(_heroSeat);
          widget.sessionManager.reseatHero(
            newSeat: seat,
            gameState: widget.gameState,
            heroName: heroName.isNotEmpty ? heroName : name,
            heroStack: heroStack > 0 ? heroStack : stack,
          );
        } else {
          // Editing hero's own seat, or adding/editing a regular player.
          // Move player if already seated elsewhere
          if (!isHero && name.isNotEmpty) {
            final lower = name.toLowerCase();
            final existingSeat = seatedPlayers[lower];
            if (existingSeat != null && existingSeat != seat) {
              widget.sessionManager.activeSeats.remove(existingSeat);
              widget.sessionManager.playerNames.remove(existingSeat);
              widget.sessionManager.playerStacks.remove(existingSeat);
              widget.sessionManager.playerIds.remove(existingSeat);
              widget.gameState.setPlayerActive(existingSeat, false);
            }
          }
          widget.sessionManager.playerNames[seat] = name;
          widget.sessionManager.playerStacks[seat] = stack;
          widget.sessionManager.activeSeats.add(seat);
          // Activating an already-active player would reset their betting
          // state mid-hand (betThisRound/totalContribution) — only activate
          // seats that are currently inactive.
          if (!widget.gameState.players[seat - 1].isActive) {
            widget.gameState.setPlayerActive(seat, true);
          }
          widget.gameState.setPlayerStack(seat, stack);
        }
        widget.onChanged();
        setState(() {});
        // Defer so any dialog appears after SeatConfigSheet dismisses
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkButtonOnEmptySeat();
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      decoration: BoxDecoration(
        color: AppColors.bgInverse,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDecorations.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildSessionChipAndDealer(),
                    const SizedBox(height: 8),
                    _buildDivider(),
                    _buildSeatList(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottom),
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderOnInverseSubtle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n.tableManageTitle,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnInverse,
            height: 20 / 15,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/X.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  AppColors.borderLight,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionChipAndDealer() {
    final l10n = AppLocalizations.of(context);
    final elapsed = _sessionElapsed();
    final playerCount = widget.sessionManager.activeSeats.length;
    final btnPos = widget.gameState.buttonPosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session info chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (elapsed.isNotEmpty) ...[
                Text(
                  elapsed,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.bgInverse,
                    height: 16 / 11,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              SvgPicture.asset(
                'assets/icons/Users.svg',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(AppColors.bgInverse, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Text(
                '$playerCount',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.bgInverse,
                  height: 16 / 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dealer Button row — tap to cycle
        GestureDetector(
          onTap: _cycleButton,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                l10n.tableManagementDealerButton,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textOnInverse,
                  height: 22 / 15,
                ),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$btnPos',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bgInverse,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(color: AppColors.borderOnInverseSubtle, height: 1, thickness: 1);
  }

  Widget _buildSeatList() {
    const totalSeats = 9;
    final items = <Widget>[];
    for (int seat = 1; seat <= totalSeats; seat++) {
      final isActive = widget.sessionManager.activeSeats.contains(seat);
      items.add(isActive ? _buildActiveSeatRow(seat) : _buildEmptySeatRow(seat));
      if (seat < totalSeats) items.add(_buildDivider());
    }
    return Column(children: items);
  }

  Widget _buildActiveSeatRow(int seat) {
    final isHero = seat == _heroSeat;
    final player = widget.gameState.players[seat - 1];
    final l10n = AppLocalizations.of(context);
    final name = widget.sessionManager.playerNames[seat] ??
        l10n.tableManagementSeatLabel(seat);
    final stack = player.currentStack;
    final position = _getPositionForSeat(seat);
    final displayName = isHero ? l10n.tableManagementYouSuffix(name) : name;

    return GestureDetector(
      onTap: () => _openSeatConfig(seat),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$seat',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bgInverse,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textOnInverse,
                        height: 22 / 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.gameState.formatCurrency(stack),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOnInverse,
                      height: 22 / 15,
                    ),
                  ),
                ],
              ),
            ),
            if (position.isNotEmpty)
              Container(
                width: 38,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.borderOnInverseSubtle,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  position,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textOnInverse,
                    height: 20 / 13,
                  ),
                ),
              )
            else
              const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySeatRow(int seat) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _openSeatConfig(seat),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.borderOnInverseSubtle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$seat',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnInverse,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.tableManagementAddPlayer,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.borderLight,
                  height: 22 / 15,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: AppColors.bgInverse, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                border: Border.all(color: AppColors.borderLight),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.commonCancel,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnInverse,
                  height: 20 / 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.commonSave,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bgInverse,
                  height: 20 / 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Button-on-empty-seat guard
  // ---------------------------------------------------------------------------

  void _checkButtonOnEmptySeat() {
    final btnPos = widget.gameState.buttonPosition;
    if (widget.sessionManager.activeSeats.contains(btnPos)) return;

    int? nearestActive;
    for (int i = 1; i <= 9; i++) {
      final candidate = ((btnPos - 1 + i) % 9) + 1;
      if (widget.sessionManager.activeSeats.contains(candidate)) {
        nearestActive = candidate;
        break;
      }
    }
    if (nearestActive == null) return;
    final moveTo = nearestActive;

    final l10n = AppLocalizations.of(context);
    _showConfirmDialog(
      title: l10n.tableButtonOnEmpty,
      body: 'The dealer button is on Seat $btnPos which is now empty. Move it to Seat $moveTo?',
      cancelLabel: l10n.seatKeep,
      confirmLabel: l10n.seatMove,
      onConfirm: () {
        if (!mounted) return;
        setState(() {
          widget.gameState.buttonPosition = moveTo;
          widget.sessionManager.buttonPosition = moveTo;
          widget.sessionManager.actualSBSeat = widget.gameState.effectiveSBPosition;
          widget.sessionManager.actualBBSeat = widget.gameState.effectiveBBPosition;
        });
        widget.onChanged();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable Figma-spec confirmation dialog (node 652-3316)
  //
  // White modal, 24px radius, X close top-right, black warning icon square,
  // centred title + body, Cancel (outlined) + primary action (filled) buttons.
  // ---------------------------------------------------------------------------

  void _showConfirmDialog({
    required String title,
    required String body,
    required String cancelLabel,
    required String confirmLabel,
    Color? confirmColor,
    required VoidCallback onConfirm,
  }) {
    final resolvedConfirmColor = confirmColor ?? AppColors.bgPrimary;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgInverse,
            borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // X close — right-aligned per Figma items-end
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/X.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        AppColors.borderLight,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Icon + title + body — centred
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    // Black rounded square with warning icon
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                      ),
                      child: Icon(
                        Icons.warning_rounded,
                        color: AppColors.bgInverse,
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textOnInverse,
                        height: 1.44,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.borderLight,
                        height: 22 / 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Cancel + Confirm buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cancelLabel,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOnInverse,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: resolvedConfirmColor,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          confirmLabel,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bgInverse,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
