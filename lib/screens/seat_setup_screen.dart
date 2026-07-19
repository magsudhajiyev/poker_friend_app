import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import '../utils/poker_positions.dart';
import '../services/display_identity_service.dart';
import '../services/free_tier_limits.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../models/poker_game_state.dart';
import '../models/game_types.dart';
import '../widgets/poker_table_widget.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'poker_hand_screen.dart';
import 'my_opponents_screen.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/components/buttons/primary_pill_button.dart';
import '../design_system/components/buttons/outlined_pill_button.dart';
import '../design_system/components/app_toggle.dart';

class SeatSetupScreen extends StatefulWidget {
  final int? playerCount;
  final int? buttonPosition;
  final int? currentSeat;
  final PokerSessionManager? sessionManager;
  final bool isInitialSetup;
  final bool isCashGame;
  final PokerGameState? gameState;

  // Session parameters from Session Setup
  final String? sessionName;
  final double? buyInAmount;
  final double? startingStack;
  final GameType? gameType;
  final double? smallBlind;
  final double? bigBlind;
  final bool? hasBBante;

  const SeatSetupScreen({
    Key? key,
    this.playerCount,
    this.buttonPosition,
    this.currentSeat,
    this.sessionManager,
    this.isInitialSetup = true,
    this.isCashGame = true,
    this.gameState,
    this.sessionName,
    this.buyInAmount,
    this.startingStack,
    this.gameType,
    this.smallBlind,
    this.bigBlind,
    this.hasBBante,
  }) : super(key: key);

  @override
  _SeatSetupScreenState createState() => _SeatSetupScreenState();
}

class _SeatSetupScreenState extends State<SeatSetupScreen> {
  int? selectedSeat;
  int? selectedButtonPosition;
  Map<int, TextEditingController> nameControllers = {};
  Map<int, TextEditingController> stackControllers = {};
  Map<int, bool> seatActive = {};
  List<Opponent> allOpponents = [];
  Map<String, OpponentStats> opponentStats = {};
  Map<int, bool> showSaveOpponentTip = {};
  Offset? buttonDragPosition;
  bool isDraggingButton = false;
  final GlobalKey _tableKey = GlobalKey(debugLabel: 'seatTable');
  final GlobalKey _buttonTokenKey = GlobalKey(debugLabel: 'buttonToken');

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  bool _isButtonLocked() {
    if (widget.gameState == null) return false;
    for (final player in widget.gameState!.players) {
      if (player.isActive && player.hasActed) {
        return true;
      }
    }
    return false;
  }

  bool _areSeatChangesLocked() {
    if (widget.gameState == null) return false;
    for (final player in widget.gameState!.players) {
      if (player.isActive && player.hasActed) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    selectedSeat = widget.currentSeat;
    selectedButtonPosition = widget.buttonPosition ?? 1;

    for (int i = 1; i <= 9; i++) {
      if (widget.isInitialSetup) {
        seatActive[i] = true;
      } else if (widget.gameState != null) {
        try {
          final player = widget.gameState!.players.firstWhere((p) => p.playerId == i);
          seatActive[i] = player.isActive;
        } catch (e) {
          seatActive[i] = false;
        }
      } else {
        seatActive[i] = widget.sessionManager?.isPlayerActive(i) ?? false;
      }

      if (seatActive[i] == true) {
        nameControllers[i] = TextEditingController(
          text: widget.sessionManager?.getPlayerName(i) ?? ''
        );
      } else {
        nameControllers[i] = TextEditingController(text: '');
      }

      stackControllers[i] = TextEditingController(
        text: _getCurrentStackForSeat(i)
      );
    }

    _loadOpponents();
    _scheduleOnboardingTour();
  }

  void _scheduleOnboardingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || _tableKey.currentContext == null) return;
      SeatSetupTour(tableKey: _tableKey).show(context);
    });
  }

  String _getCurrentStackForSeat(int seatNumber) {
    if (widget.gameState != null && !widget.isInitialSetup) {
      final currentStack = widget.gameState!.getPlayerStack(seatNumber);
      return widget.isCashGame ? currentStack.toStringAsFixed(2) : currentStack.toInt().toString();
    }
    if (widget.startingStack != null) {
      return widget.isCashGame
          ? widget.startingStack!.toStringAsFixed(2)
          : widget.startingStack!.toInt().toString();
    }
    return widget.isCashGame ? '100.00' : '1500';
  }

  @override
  void dispose() {
    nameControllers.values.forEach((controller) => controller.dispose());
    stackControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadOpponents() async {
    try {
      final opponents = await OpponentService.getAllOpponents();
      final statsMap = <String, OpponentStats>{};

      for (final opponent in opponents) {
        final stats = await OpponentStatsService.getOpponentStats(opponent.id);
        if (stats != null) {
          statsMap[opponent.name] = stats;
        }
      }

      setState(() {
        allOpponents = opponents;
        opponentStats = statsMap;
      });
    } catch (e) {
      debugPrint('Failed to load opponents: $e');
    }
  }

  List<String> _getSuggestions(String query) {
    if (query.isEmpty) return [];
    return allOpponents
        .where((opponent) => opponent.name.toLowerCase().contains(query.toLowerCase()))
        .map((opponent) => opponent.name)
        .take(5)
        .toList();
  }

  void _checkIfShouldShowSaveTip(int seatNumber, String name) {
    if (name.trim().isEmpty) {
      setState(() {
        showSaveOpponentTip[seatNumber] = false;
      });
      return;
    }

    final existingOpponent = allOpponents
        .where((opponent) => opponent.name.toLowerCase() == name.toLowerCase())
        .isNotEmpty;

    final isPositionName = PokerPositions.isPositionName(name);

    setState(() {
      showSaveOpponentTip[seatNumber] = !existingOpponent && !isPositionName;
    });
  }

  Color _getColorForOpponent(OpponentColor color) {
    switch (color) {
      case OpponentColor.red:
        return Colors.red;
      case OpponentColor.blue:
        return Colors.blue;
      case OpponentColor.green:
        return Colors.green;
      case OpponentColor.orange:
        return Colors.orange;
      case OpponentColor.purple:
        return Colors.purple;
      case OpponentColor.teal:
        return Colors.teal;
      case OpponentColor.pink:
        return Colors.pink;
      case OpponentColor.indigo:
        return Colors.indigo;
    }
  }

  String _getPositionForActiveSeat(int seatNumber) {
    List<int> activeSeats = [];
    for (int i = 1; i <= 9; i++) {
      if (seatActive[i] == true) {
        activeSeats.add(i);
      }
    }

    if (activeSeats.isEmpty) return '';
    if (!activeSeats.contains(seatNumber)) return AppLocalizations.of(context).seatSetupEmpty;

    final buttonPos = selectedButtonPosition ?? widget.buttonPosition ?? 1;
    return PokerPositions.getPositionNameForActivePlayers(seatNumber, buttonPos, activeSeats);
  }



  void _showSeatDialog(int seatNumber) {
    final originalSelectedSeat = selectedSeat;
    final originalName = nameControllers[seatNumber]?.text ?? '';
    final originalStack = stackControllers[seatNumber]?.text ?? '';

    bool tempIsMySeat = selectedSeat == seatNumber;
    String tempName = originalName;
    String tempStack = originalStack;
    bool tempSaveAsOpponent = false;
    List<String> suggestions = [];

    final tempNameController = TextEditingController(text: tempName);
    final tempStackController = TextEditingController(text: tempStack);

    void saveChanges() {
      Navigator.pop(context, {
        'save': true,
        'isActive': tempName.isNotEmpty || tempIsMySeat,
        'isMySeat': tempIsMySeat,
        'name': tempName,
        'stack': tempStack,
        'saveAsOpponent': tempSaveAsOpponent,
      });
    }

    void cancelChanges() {
      Navigator.pop(context, null);
    }

    final mySeatKey = GlobalKey(debugLabel: 'mySeat');
    final playerNameKey = GlobalKey(debugLabel: 'playerName');
    final saveOpponentKey = GlobalKey(debugLabel: 'saveOpponent');
    bool _dialogTourShown = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!_dialogTourShown &&
              OnboardingState.isOnboardingActive &&
              OnboardingState.seatDialogTourPending) {
            _dialogTourShown = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              SeatDialogTour(
                seatToggleKey: mySeatKey,
                mySeatKey: mySeatKey,
                playerNameKey: playerNameKey,
                saveOpponentKey: saveOpponentKey,
              ).show(context);
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── HEADER ────────────────────────────────────
                    Row(
                      children: [
                        const SizedBox(width: 18),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Seat $seatNumber',
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 20 / 15,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: cancelChanges,
                          child: _buildIcon(
                            'icons/figma_icons/close.svg',
                            18,
                            AppColors.contentInactive,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── THIS IS MY SEAT ───────────────────────────
                    GestureDetector(
                      key: mySeatKey,
                      onTap: _areSeatChangesLocked() ? null : () {
                        setDialogState(() {
                          tempIsMySeat = !tempIsMySeat;
                          if (tempIsMySeat) {
                            final userName = DisplayIdentityService.cachedDisplayIdentity;
                            if (userName.isNotEmpty) {
                              tempName = userName;
                              tempNameController.text = userName;
                              suggestions = _getSuggestions(userName);
                            }
                            if (widget.startingStack != null) {
                              tempStack = widget.gameType == GameType.cash
                                  ? widget.startingStack!.toStringAsFixed(2)
                                  : widget.startingStack!.toInt().toString();
                              tempStackController.text = tempStack;
                            }
                          }
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tempIsMySeat
                                    ? AppColors.bgPrimary
                                    : AppColors.contentInactive,
                                width: 1.5,
                              ),
                            ),
                            child: tempIsMySeat
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.bgPrimary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context).seatSetupThisIsMySeat,
                            style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ─── PLAYER NAME + SAVE-AS-OPPONENT (grouped) ──
                    // Both live inside a single card so the toggle
                    // visually reads as a modifier of the Name field
                    // rather than as another input row.
                    Column(
                      key: playerNameKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).seatSetupPlayerName,
                          style: AppTypography.ibm(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            border: Border.all(
                                color: AppColors.borderStrong, width: 1.5),
                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: tempNameController,
                                enabled: !_areSeatChangesLocked(),
                                style: AppTypography.ibm(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                  hintText: AppLocalizations.of(context)
                                      .seatSetupPlayerName,
                                  hintStyle: AppTypography.ibm(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    tempName = value;
                                    suggestions = _getSuggestions(value);
                                  });
                                },
                              ),
                              // Hairline between the input and the
                              // toggle so the two rows read as siblings
                              // inside the same card.
                              Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              Padding(
                                key: saveOpponentKey,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Save as opponent',
                                      style: AppTypography.ibm(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFB2B2B2),
                                      ),
                                    ),
                                    AppToggle(
                                      value: tempSaveAsOpponent,
                                      onChanged: (val) => setDialogState(
                                          () => tempSaveAsOpponent = val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Inline autocomplete suggestions
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ...suggestions.map((suggestion) {
                            final opponent = allOpponents.firstWhere(
                              (o) => o.name == suggestion,
                              orElse: () => allOpponents.first,
                            );
                            final color = _getColorForOpponent(opponent.color);
                            final initials = suggestion.length >= 2
                                ? suggestion.substring(0, 2).toUpperCase()
                                : suggestion.toUpperCase();
                            // Find which seat this opponent is currently at
                            String? assignedSeat;
                            for (int i = 1; i <= 9; i++) {
                              if (i != seatNumber &&
                                  nameControllers[i]?.text == suggestion) {
                                assignedSeat = 'Seat $i';
                                break;
                              }
                            }
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempName = suggestion;
                                  tempNameController.text = suggestion;
                                  tempNameController.selection =
                                      TextSelection.fromPosition(TextPosition(
                                          offset: suggestion.length));
                                  suggestions = [];
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: AppTypography.ibm(
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      suggestion,
                                      style: AppTypography.ibm(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        height: 20 / 13,
                                      ),
                                    ),
                                    if (assignedSeat != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentSecondary,
                                          borderRadius:
                                              BorderRadius.circular(AppDecorations.radiusFull),
                                        ),
                                        child: Text(
                                          assignedSeat,
                                          style: AppTypography.ibm(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textInverse,
                                            height: 16 / 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─── STACK ─────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCashGame
                              ? AppLocalizations.of(context).seatSetupBuyInAmount
                              : AppLocalizations.of(context).seatSetupStartingChips,
                          style: AppTypography.ibm(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgInputOnInverse,
                            border: Border.all(color: AppColors.borderOnInverseSubtle),
                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                          ),
                          child: TextField(
                            controller: tempStackController,
                            enabled: !_areSeatChangesLocked(),
                            keyboardType: TextInputType.numberWithOptions(
                                decimal: widget.isCashGame),
                            style: AppTypography.ibm(
                              fontSize: 15,
                              color: AppColors.textInverse,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              hintText: r'$',
                              hintStyle: AppTypography.ibm(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onChanged: (value) {
                              if (widget.isCashGame) {
                                if (value.isNotEmpty &&
                                    !RegExp(r'^\d*\.?\d{0,2}$')
                                        .hasMatch(value)) {
                                  tempStackController.text = tempStackController
                                      .text
                                      .substring(
                                          0,
                                          tempStackController.text.length - 1);
                                  tempStackController.selection =
                                      TextSelection.fromPosition(TextPosition(
                                          offset:
                                              tempStackController.text.length));
                                }
                              } else {
                                if (value.isNotEmpty &&
                                    !RegExp(r'^\d+$').hasMatch(value)) {
                                  tempStackController.text = tempStackController
                                      .text
                                      .substring(
                                          0,
                                          tempStackController.text.length - 1);
                                  tempStackController.selection =
                                      TextSelection.fromPosition(TextPosition(
                                          offset:
                                              tempStackController.text.length));
                                }
                              }
                              tempStack = tempStackController.text;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ─── FOOTER ────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedPillButton(
                            label: AppLocalizations.of(context).commonBack,
                            onTap: cancelChanges,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PrimaryPillButton(
                            label: AppLocalizations.of(context).commonSave,
                            onTap: saveChanges,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 24,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((result) {
      if (result != null && result['save'] == true) {
        final isActive = result['isActive'] as bool;
        final isMySeat = result['isMySeat'] as bool;
        final name = result['name'] as String;
        final stack = result['stack'] as String;
        final doSaveOpponent = result['saveAsOpponent'] as bool;

        setState(() {
          seatActive[seatNumber] = isActive;

          if (!isActive) {
            nameControllers[seatNumber]?.text = '';
            final defaultStack = widget.startingStack != null
                ? (widget.gameType == GameType.cash
                    ? widget.startingStack!.toStringAsFixed(2)
                    : widget.startingStack!.toInt().toString())
                : (widget.isCashGame ? '100.00' : '1500');
            stackControllers[seatNumber]?.text = defaultStack;
            widget.sessionManager?.setPlayerName(seatNumber, 'Player $seatNumber');
            if (selectedSeat == seatNumber) selectedSeat = null;
          } else {
            nameControllers[seatNumber]?.text = name;
            stackControllers[seatNumber]?.text = stack;

            if (isMySeat && selectedSeat != seatNumber) {
              if (selectedSeat != null && selectedSeat != seatNumber) {
                _restoreDefaultsForPreviousSeat(selectedSeat);
              }
              selectedSeat = seatNumber;
            } else if (!isMySeat && originalSelectedSeat == seatNumber) {
              selectedSeat = null;
            }

            widget.sessionManager?.setPlayerName(seatNumber, name);
          }

          showSaveOpponentTip[seatNumber] = false;
        });

        if (doSaveOpponent && name.isNotEmpty && !isMySeat) {
          _saveOpponentFromDialog(name);
        }
      }

      Future.delayed(const Duration(milliseconds: 350), () {
        tempNameController.dispose();
        tempStackController.dispose();
      });

      if (OnboardingState.isOnboardingActive &&
          OnboardingState.buttonTokenTourPending) {
        OnboardingState.buttonTokenTourPending = false;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          ButtonTokenTour(buttonTokenKey: _buttonTokenKey).show(context);
        });
      }
    });
  }

  Future<void> _saveOpponentFromDialog(String name) async {
    if (!FreeTierLimits.canCreateAnotherOpponent(allOpponents.length)) {
      if (mounted) await FreeTierLimits.showOpponentLimitDialog(context);
      return;
    }
    try {
      final existing = await OpponentService.findOpponentByName(name);
      if (existing != null) return;
      final opponent = OpponentService.createNewOpponent(name: name);
      await OpponentService.saveOpponent(opponent);
      MyOpponentsScreen.invalidateCache();
      await _loadOpponents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).seatSetupOpponentSaved),
          backgroundColor: AppColors.accentPrimary,
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isInitialSetup ? l10n.seatSetupTitle : l10n.seatManagePlayers,
                              style: AppTypography.ibm(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              widget.isInitialSetup
                                  ? 'Click seat to configure. Drag button to position'
                                  : _isButtonLocked()
                                      ? 'Button locked - hand in progress'
                                      : l10n.seatUpdatePlayerInfo,
                              style: AppTypography.ibm(
                                fontSize: 14,
                                color: _isButtonLocked() ? Colors.orange : Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Table + buttons scroll together
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Visual Poker Table — fixed height based on screen
                        SizedBox(
                          key: _tableKey,
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: PokerTableWidget(
                            activeSeatMap: seatActive,
                            seatLabels: {
                              for (int i = 1; i <= 9; i++)
                                i: nameControllers[i]?.text ?? '',
                            },
                            buttonPosition: selectedButtonPosition ?? widget.buttonPosition,
                            onSeatTap: _showSeatDialog,
                            showDealerButton: true,
                            isDealerButtonDraggable: !_isButtonLocked(),
                            onDealerButtonMoved: (newSeat) {
                              setState(() {
                                selectedButtonPosition = newSeat;
                                isDraggingButton = false;
                              });
                            },
                          ),
                        ),

                        // Bottom buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            children: [
                              // Start Session button
                              GestureDetector(
                                onTap: _saveChanges,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary,
                                    borderRadius: BorderRadius.circular(110),
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.isInitialSetup ? l10n.seatStartSession : l10n.seatSaveChanges,
                                      style: AppTypography.ibm(
                                        color: Colors.black,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.43,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Cancel button
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    AppLocalizations.of(context).seatSetupCancel,
                                    style: AppTypography.ibm(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 60), // Space for bottom nav
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _restoreDefaultsForPreviousSeat(int? previousSeat) {
    if (previousSeat == null) return;

    final userName = DisplayIdentityService.cachedDisplayIdentity;
    final nameController = nameControllers[previousSeat];
    final stackController = stackControllers[previousSeat];

    if (nameController != null && stackController != null) {
      final l10n = AppLocalizations.of(context);
      bool wasUserSeat = nameController.text == userName ||
                        nameController.text == l10n.seatYou ||
                        nameController.text.isEmpty;

      if (wasUserSeat) {
        nameController.text = 'Player $previousSeat';

        if (widget.startingStack != null) {
          stackController.text = widget.gameType == GameType.cash
              ? widget.startingStack!.toStringAsFixed(2)
              : widget.startingStack!.toInt().toString();
        } else {
          stackController.text = widget.isCashGame ? '100.00' : '1500';
        }

        seatActive[previousSeat] = false;
        widget.sessionManager?.setPlayerName(previousSeat, 'Player $previousSeat');
      }
    }
  }

  void _autoInsertUsernameForSeat(int seatNumber) {
    final userName = DisplayIdentityService.cachedDisplayIdentity;
    final controller = nameControllers[seatNumber];

    if (controller != null && userName.isNotEmpty) {
      controller.text = userName;
      seatActive[seatNumber] = true;
      widget.sessionManager?.setPlayerName(seatNumber, userName);
    }
  }

  Future<void> _saveChanges() async {
    if (widget.isInitialSetup && selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).seatSetupSelectYourSeat),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if button is on an empty seat
    final btnPos = selectedButtonPosition ?? widget.buttonPosition ?? 1;
    final btnSeatActive = seatActive[btnPos] ?? false;
    if (!btnSeatActive) {
      final moved = await _showButtonOnEmptySeatWarning(btnPos);
      if (!mounted) return;
      if (moved == null) return; // User cancelled
    }

    Map<int, double> playerStacks = {};

    for (int seat = 1; seat <= 9; seat++) {
      final isActive = seatActive[seat] ?? false;
      final name = nameControllers[seat]?.text ?? '';

      if (isActive) {
        widget.sessionManager?.addPlayer(seat, name);

        final stackText = stackControllers[seat]?.text ?? '0';
        double stackSize = 0.0;
        try {
          stackSize = double.parse(stackText);
        } catch (e) {
          stackSize = widget.startingStack ?? (widget.isCashGame ? 100.0 : 1500.0);
        }
        playerStacks[seat] = stackSize;
        widget.sessionManager?.setPlayerStack(seat, stackSize);
      } else {
        widget.sessionManager?.removePlayer(seat);
      }
    }

    if (widget.sessionName != null && widget.smallBlind != null && widget.bigBlind != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PokerHandScreen(
            smallBlind: widget.smallBlind!,
            bigBlind: widget.bigBlind!,
            numberOfPlayers: 9,
            gameType: widget.gameType ?? GameType.cash,
            hasBBante: widget.hasBBante ?? false,
            ante: (widget.hasBBante ?? false) ? widget.bigBlind! : 0,
            sessionName: widget.sessionName,
            buyInAmount: widget.buyInAmount,
            startingStack: widget.startingStack,
            initialSeat: selectedSeat,
            initialButtonPosition: selectedButtonPosition ?? widget.buttonPosition,
            sessionManager: widget.sessionManager,
          ),
        ),
      );
    } else {
      Navigator.pop(context, {
        'seat': selectedSeat,
        'buttonPosition': selectedButtonPosition ?? widget.buttonPosition,
        'playerStacks': playerStacks,
        'isCashGame': widget.isCashGame,
      });
    }
  }

  /// Shows a warning dialog when the button is on an empty seat.
  /// Returns the new button seat if auto-moved, or non-null if user chose to keep it.
  /// Returns null if user cancelled.
  Future<int?> _showButtonOnEmptySeatWarning(int currentBtnSeat) async {
    final l10n = AppLocalizations.of(context);
    // Find nearest active seat clockwise
    int? nearestActive;
    for (int i = 1; i <= 9; i++) {
      final candidate = ((currentBtnSeat - 1 + i) % 9) + 1;
      if (seatActive[candidate] ?? false) {
        nearestActive = candidate;
        break;
      }
    }

    if (nearestActive == null) return currentBtnSeat; // No active seats at all

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant4,
        title: Text(
          'Button on Empty Seat',
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'The dealer button is on Seat $currentBtnSeat which is empty. Move it to Seat $nearestActive?',
          style: AppTypography.ibm(
            color: AppColors.textDisabled,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.seatKeep, style: AppTypography.ibm(color: AppColors.textDisabled)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.seatMove, style: AppTypography.ibm(color: AppColors.accentPrimary)),
          ),
        ],
      ),
    );

    if (result == null) return null; // Dismissed
    if (result == true) {
      setState(() {
        selectedButtonPosition = nearestActive;
      });
      return nearestActive;
    }
    return currentBtnSeat; // User chose to keep
  }
}
