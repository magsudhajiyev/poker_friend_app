import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../models/dealer_session.dart';
import '../../models/hand_state_machine.dart';
import '../../services/seat_service.dart';
import '../../services/dealer_service.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../utils/number_formatter.dart';
import '../../widgets/hole_cards_dialog.dart';
import '../../models/club_event.dart';
import '../../l10n/app_localizations.dart';
import '../hand_actions_page_view.dart';
import '../spectator/event_rankings_screen.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';

/// Player session screen for participating in dealer-assisted sessions.
/// Shows real-time hand updates, allows player to input hole cards, notes, and tags.
class PlayerSessionScreen extends StatefulWidget {
  final String clubId;
  final String tableId;
  final int seatNumber;

  const PlayerSessionScreen({
    Key? key,
    required this.clubId,
    required this.tableId,
    required this.seatNumber,
  }) : super(key: key);

  @override
  State<PlayerSessionScreen> createState() => _PlayerSessionScreenState();
}

class _PlayerSessionScreenState extends State<PlayerSessionScreen> {
  // Subscriptions
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _sessionDocSubscription;
  StreamSubscription? _handSubscription;
  StreamSubscription? _seatSubscription;

  // Session state
  DealerSession? _session;
  Map<String, dynamic>? _currentHand;
  List<Map<String, dynamic>> _handHistory = [];
  bool _isLoading = true;
  String? _error;

  // Session status
  DealerSessionStatus _sessionStatus = DealerSessionStatus.active;
  bool get _isPaused => _sessionStatus == DealerSessionStatus.paused;

  // Event info
  String? _eventName;
  ClubEvent? _event;

  // Player's seat info
  double _myStack = 0;

  // Hand state from dealer
  int _handNumber = 0;
  double _potAmount = 0;
  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic>? _boardCards;
  bool _isHandActive = false;
  bool _isShowingExitDialog = false;

  // Player input (persisted per hand)
  String? _myCard1;
  String? _myCard2;
  String _handNotes = '';
  List<String> _handTags = [];

  // Available tags
  final List<String> _availableTags = [
    'Bluff',
    'Value',
    'Mistake',
    'Cooler',
    'Hero Call',
    'Exploit',
    'Tough Spot',
    'Easy Fold',
  ];

  // Hand history expansion
  bool _isHistoryExpanded = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _sessionDocSubscription?.cancel();
    _handSubscription?.cancel();
    _seatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _seatSubscription = SeatService.watchSeat(
        clubId: widget.clubId,
        tableId: widget.tableId,
        seatNumber: widget.seatNumber,
      ).listen((seat) {
        if (!mounted) return;

        if (seat == null || !seat.isOccupied || seat.playerId != AuthService.userId) {
          _showRemovedFromTableDialog();
          return;
        }

        setState(() {
          _myStack = seat.chipStack ?? 0;
        });
      });

      _sessionSubscription = DealerService.watchActiveSessionForTable(
        clubId: widget.clubId,
        tableId: widget.tableId,
      ).listen(_onSessionUpdate);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSessionUpdate(DealerSession? session) {
    if (!mounted) return;

    if (session == null && _session != null) {
      _showSessionEndedDialog();
      return;
    }

    if (session != null) {
      final isFirstLoad = _session == null;
      final sessionChanged = _session != null && _session!.id != session.id;
      final oldHandId = _session?.currentHandId;
      final newHandId = session.currentHandId;

      setState(() {
        _session = session;
        _sessionStatus = session.status;
      });

      if (isFirstLoad || sessionChanged) {
        if (sessionChanged) {
          setState(() {
            _handHistory = [];
            _currentHand = null;
            _actions = [];
            _boardCards = null;
          });
        }
        _loadExistingHands(session.id);
        _loadEventName(session);

        // Watch session doc directly for status changes (backup for session-end detection)
        _sessionDocSubscription?.cancel();
        _sessionDocSubscription = DealerService.watchSession(session.id).listen((s) {
          if (!mounted) return;
          if (s != null && s.status == DealerSessionStatus.ended) {
            _showSessionEndedDialog();
          }
        });
      }

      if (newHandId != oldHandId) {
        _handSubscription?.cancel();

        if (!isFirstLoad && oldHandId != null && _currentHand != null) {
          _addToHistory(_currentHand!);
        }

        _resetPlayerInput();

        if (newHandId != null) {
          _watchCurrentHand(session.id, newHandId);
        } else {
          setState(() {
            _isHandActive = false;
          });
        }
      }

      if (session.status == DealerSessionStatus.ended) {
        _showSessionEndedDialog();
      }
    }
  }

  void _watchCurrentHand(String sessionId, String handId) {
    _loadPlayerHandData(sessionId, handId);

    _handSubscription = DealerService.watchCurrentHand(sessionId, handId).listen((handData) {
      if (!mounted || handData == null) return;

      final actions = (handData['actions'] as List<dynamic>?) ?? [];
      final status = handData['status'] as String?;
      final handNumber = handData['handNumber'] as int? ?? 0;
      final boardCards = handData['boardCards'] as Map<String, dynamic>?;

      double pot = _calculatePotFromActions(handData);

      setState(() {
        _currentHand = handData;
        _handNumber = handNumber;
        _potAmount = pot;
        _actions = actions.cast<Map<String, dynamic>>();
        _boardCards = boardCards;
        _isHandActive = status == 'active';
      });

      if (status == 'completed' && _isHandActive) {
        final winnerId = handData['winnerId'] as int?;
        if (winnerId != null) {
          _showHandResult(winnerId, pot);
        }
      }
    });
  }

  Future<void> _loadPlayerHandData(String sessionId, String handId) async {
    final odPlayerId = AuthService.userId;
    if (odPlayerId == null) return;

    try {
      final playerData = await DealerService.getPlayerHandData(
        sessionId: sessionId,
        handId: handId,
        odPlayerId: odPlayerId,
      );

      if (playerData != null && mounted) {
        final holeCards = playerData['holeCards'] as Map<String, dynamic>?;
        final notes = playerData['notes'] as String?;
        final tags = (playerData['tags'] as List<dynamic>?)?.cast<String>();

        setState(() {
          if (holeCards != null) {
            _myCard1 = holeCards['card1'] as String?;
            _myCard2 = holeCards['card2'] as String?;
          }
          if (notes != null) {
            _handNotes = notes;
          }
          if (tags != null) {
            _handTags = List.from(tags);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading player hand data: $e');
    }
  }

  double _calculatePotFromActions(Map<String, dynamic> handData) {
    final actions = (handData['actions'] as List<dynamic>?) ?? [];
    final smallBlind = (handData['smallBlind'] as num?)?.toDouble() ?? 1.0;
    final bigBlind = (handData['bigBlind'] as num?)?.toDouble() ?? 2.0;
    final hasBBante = handData['hasBBante'] as bool? ?? false;

    double pot = smallBlind + bigBlind;
    if (hasBBante) pot += bigBlind;

    for (final a in actions) {
      final action = a as Map<String, dynamic>;
      final actionType = action['action'] as String?;
      final amount = (action['amount'] as num?)?.toDouble();

      if (amount != null && actionType != null) {
        switch (actionType) {
          case 'call':
          case 'bet':
          case 'raise':
          case 'all-in':
            pot += amount;
            break;
        }
      }
    }

    return pot;
  }

  void _resetPlayerInput() {
    setState(() {
      _myCard1 = null;
      _myCard2 = null;
      _handNotes = '';
      _handTags = [];
    });
  }

  void _addToHistory(Map<String, dynamic> hand) {
    final annotatedHand = Map<String, dynamic>.from(hand);

    if (_myCard1 != null && _myCard2 != null) {
      annotatedHand['playerHoleCards'] = {'card1': _myCard1, 'card2': _myCard2};
    }
    if (_handNotes.isNotEmpty) {
      annotatedHand['playerNotes'] = _handNotes;
    }
    if (_handTags.isNotEmpty) {
      annotatedHand['playerTags'] = _handTags;
    }

    setState(() {
      _handHistory.insert(0, annotatedHand);
      if (_handHistory.length > 20) {
        _handHistory = _handHistory.sublist(0, 20);
      }
    });
  }

  Future<void> _loadExistingHands(String sessionId) async {
    try {
      final hands = await DealerService.getSessionHands(sessionId);

      final completedHands = hands
          .where((h) => h['status'] == 'completed')
          .toList()
        ..sort((a, b) => (b['handNumber'] as int? ?? 0)
            .compareTo(a['handNumber'] as int? ?? 0));

      if (mounted) {
        setState(() {
          _handHistory = completedHands.take(20).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading existing hands: $e');
    }
  }

  Future<void> _loadEventName(DealerSession session) async {
    if (session.eventId == null) {
      setState(() {
        _eventName = null;
        _event = null;
      });
      return;
    }

    try {
      final event = await EventService.getEvent(session.clubId, session.eventId!);
      if (mounted && event != null) {
        setState(() {
          _eventName = event.name;
          _event = event;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _showSessionEndedDialog() {
    if (_isShowingExitDialog) return;
    _isShowingExitDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
        title: Text(
          AppLocalizations.of(context).playerSessionEndedTitle,
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          AppLocalizations.of(context).playerSessionEndedBody,
          style: AppTypography.ibm(
            color: AppColors.textDisabled,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context).commonOk,
              style: AppTypography.ibm(
                color: AppColors.buttonPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemovedFromTableDialog() {
    if (_isShowingExitDialog) return;
    _isShowingExitDialog = true;

    _sessionSubscription?.cancel();
    _handSubscription?.cancel();
    _seatSubscription?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
        title: Text(
          AppLocalizations.of(context).playerSessionRemovedTitle,
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          AppLocalizations.of(context).playerSessionRemovedBody,
          style: AppTypography.ibm(
            color: AppColors.textDisabled,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context).commonOk,
              style: AppTypography.ibm(
                color: AppColors.buttonPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHandResult(int winnerId, double pot) {
    final isWinner = winnerId == widget.seatNumber;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWinner
              ? 'You won ${_formatAmount(pot)}!'
              : 'Seat $winnerId wins ${_formatAmount(pot)}',
          style: AppTypography.ibm(color: Colors.white),
        ),
        backgroundColor: isWinner ? AppColors.limeGreen : AppColors.bgSurface,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _editHoleCards() async {
    final usedCards = <String>{};

    if (_boardCards != null) {
      final flop = _boardCards!['flop'] as List?;
      if (flop != null) usedCards.addAll(flop.cast<String>());
      final turn = _boardCards!['turn'] as String?;
      if (turn != null) usedCards.add(turn);
      final river = _boardCards!['river'] as String?;
      if (river != null) usedCards.add(river);
    }

    final result = await showDialog<HoleCards>(
      context: context,
      builder: (context) => HoleCardsDialog(
        existingCards: (_myCard1 != null && _myCard2 != null)
            ? HoleCards(card1: _myCard1!, card2: _myCard2!)
            : null,
        usedCards: usedCards,
        title: AppLocalizations.of(context).playerSessionYourHoleCards,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _myCard1 = result.card1;
        _myCard2 = result.card2;
      });
      await _savePlayerData();
    }
  }

  Future<void> _savePlayerData() async {
    if (_session == null || _currentHand == null) return;

    final odPlayerId = AuthService.userId;
    final handId = _currentHand!['id'] as String?;

    if (odPlayerId == null || handId == null) return;

    try {
      await DealerService.savePlayerHandData(
        sessionId: _session!.id,
        handId: handId,
        odPlayerId: odPlayerId,
        card1: _myCard1,
        card2: _myCard2,
        notes: _handNotes.isNotEmpty ? _handNotes : null,
        tags: _handTags.isNotEmpty ? _handTags : null,
      );

      // Update in-memory hand history so hole cards appear in the dropdown
      if (_handHistory.isNotEmpty && mounted) {
        final idx = _handHistory.indexWhere((h) => h['id'] == handId);
        if (idx >= 0) {
          setState(() {
            if (_myCard1 != null && _myCard2 != null) {
              _handHistory[idx]['playerHoleCards'] = {'card1': _myCard1, 'card2': _myCard2};
              _handHistory[idx]['ourHoleCards'] = {'card1': _myCard1, 'card2': _myCard2};
            }
            if (_handNotes.isNotEmpty) {
              _handHistory[idx]['playerNotes'] = _handNotes;
            }
            if (_handTags.isNotEmpty) {
              _handHistory[idx]['playerTags'] = _handTags;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error saving player data: $e');
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_handTags.contains(tag)) {
        _handTags.remove(tag);
      } else {
        _handTags.add(tag);
      }
    });
    _savePlayerData();
  }

  Future<void> _leaveTable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
        title: Text(
          AppLocalizations.of(context).playerSessionLeaveTableTitle,
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          AppLocalizations.of(context).playerSessionLeaveTableBody,
          style: AppTypography.ibm(
            color: AppColors.textDisabled,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context).commonCancel,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context).commonLeave,
              style: AppTypography.ibm(
                color: AppColors.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SeatService.leaveSeat(
          clubId: widget.clubId,
          tableId: widget.tableId,
          seatNumber: widget.seatNumber,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).playerSessionFailedLeave(e.toString()),
                style: AppTypography.ibm(color: Colors.white),
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          if (_isPaused) _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dealerName = _session?.dealerName ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Back / leave button
          GestureDetector(
            onTap: _leaveTable,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventName ?? 'Table Session',
                  style: AppTypography.ibm(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).playerSessionHandNumber(_handNumber),
                      style: AppTypography.ibm(
                        fontSize: 13,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isHandActive
                            ? AppColors.limeGreen
                            : AppColors.textDisabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isHandActive ? 'LIVE' : 'WAITING',
                      style: AppTypography.ibm(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isHandActive
                            ? AppColors.limeGreen
                            : AppColors.textDisabled,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Live Rankings button (only for event sessions)
          if (_event != null) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventRankingsScreen(
                      event: _event!,
                      accessCode: _event!.accessCode,
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tealPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: AppColors.tealPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Dealer badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.buttonPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 11,
                  color: AppColors.buttonPrimary,
                ),
                const SizedBox(width: 3),
                Text(
                  dealerName,
                  style: AppTypography.ibm(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.buttonPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.buttonPrimary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).playerSessionConnecting,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                style: AppTypography.ibm(
                  color: AppColors.textDisabled,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                  ),
                  child: Text(
                    AppLocalizations.of(context).playerSessionGoBackBtn,
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      letterSpacing: -0.43,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
          const SizedBox(height: 16),
          _buildHoleCardsSection(),
          const SizedBox(height: 16),
          if (_boardCards != null) ...[
            _buildBoardCardsSection(),
            const SizedBox(height: 16),
          ],
          _buildActionsSection(),
          const SizedBox(height: 16),
          _buildNotesSection(),
          const SizedBox(height: 12),
          _buildTagsSection(),
          const SizedBox(height: 16),
          _buildHandHistorySection(),
        ],
      ),
    );
  }

  bool get _isTournament => _session?.gameType == 'tournament';
  String _formatAmount(num amount) =>
      _isTournament ? formatCompactNumber(amount) : formatCompactCurrency(amount);

  // ─── STATUS BAR ──────────────────────────────────────────────────

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.separatorDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(AppLocalizations.of(context).playerSessionSeat, '#${widget.seatNumber}', AppColors.buttonPrimary),
          _buildStatusItem(AppLocalizations.of(context).playerSessionStack, _formatAmount(_myStack), AppColors.limeGreen),
          _buildStatusItem(AppLocalizations.of(context).playerSessionPot, _formatAmount(_potAmount), const Color(0xFFFFA726)),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.mono(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.ibm(
            color: AppColors.textDisabled,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ─── HOLE CARDS ──────────────────────────────────────────────────

  Widget _buildHoleCardsSection() {
    final hasCards = _myCard1 != null && _myCard2 != null;

    return GestureDetector(
      onTap: _editHoleCards,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(
            color: hasCards
                ? AppColors.buttonPrimary.withValues(alpha: 0.3)
                : AppColors.separatorDark,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.style_rounded,
              color: hasCards ? AppColors.buttonPrimary : AppColors.textDisabled,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).playerSessionHoleCardsLabel,
              style: AppTypography.ibm(
                color: hasCards ? AppColors.buttonPrimary : AppColors.textDisabled,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (hasCards) ...[
              _buildMiniCard(_myCard1!),
              const SizedBox(width: 4),
              _buildMiniCard(_myCard2!),
              const SizedBox(width: 10),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              child: Text(
                hasCards ? 'Edit' : 'Add',
                style: AppTypography.ibm(
                  color: AppColors.buttonPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOARD CARDS ─────────────────────────────────────────────────

  Widget _buildBoardCardsSection() {
    final flop = (_boardCards?['flop'] as List?)?.cast<String>() ?? [];
    final turn = _boardCards?['turn'] as String?;
    final river = _boardCards?['river'] as String?;
    final hasCards = flop.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(
          color: hasCards
              ? const Color(0xFFFFA726).withValues(alpha: 0.3)
              : AppColors.separatorDark,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_rounded, color: Color(0xFFFFA726), size: 18),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).playerSessionBoardLabel,
            style: AppTypography.ibm(
              color: const Color(0xFFFFA726),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (hasCards) ...[
            ...flop.map((card) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildBoardCard(card),
                )),
            if (turn != null) ...[
              const SizedBox(width: 4),
              _buildBoardCard(turn),
              const SizedBox(width: 4),
            ],
            if (river != null) ...[
              _buildBoardCard(river),
            ],
          ] else
            Text(
              AppLocalizations.of(context).playerSessionNoCardsDealt,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(String card) {
    final suit = card.length > 1 ? card.substring(1) : '';
    final isRed = suit == '♥' || suit == '♦';

    return Container(
      width: 34,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card,
          style: TextStyle(
            color: isRed ? Colors.red : Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─── ACTIONS ─────────────────────────────────────────────────────

  /// Tracks which streets are expanded in the actions section.
  final Set<String> _expandedStreets = {};

  Widget _buildActionsSection() {
    if (_actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(color: AppColors.separatorDark),
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context).playerSessionWaitingForAction,
            style: AppTypography.ibm(
              color: AppColors.textDisabled,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final actionsByStreet = <String, List<Map<String, dynamic>>>{
      'preflop': [],
      'flop': [],
      'turn': [],
      'river': [],
    };

    for (final action in _actions) {
      final street = (action['street'] as String?) ?? 'preflop';
      actionsByStreet[street]?.add(action);
    }

    // Find the latest street with actions — keep it expanded by default
    final nonEmptyStreets = actionsByStreet.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    if (nonEmptyStreets.isNotEmpty) {
      final latestStreet = nonEmptyStreets.last;
      // Auto-expand the latest street, collapse completed ones
      if (!_expandedStreets.contains(latestStreet)) {
        _expandedStreets.add(latestStreet);
        // Collapse previous streets when a new one starts
        for (final s in nonEmptyStreets) {
          if (s != latestStreet) _expandedStreets.remove(s);
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.separatorDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.textDisabled, size: 18),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).playerSessionActionsLabel,
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...actionsByStreet.entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => _buildStreetActions(e.key, e.value)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStreetActions(String street, List<Map<String, dynamic>> actions) {
    final isExpanded = _expandedStreets.contains(street);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedStreets.remove(street);
              } else {
                _expandedStreets.add(street);
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.bgPrimary,
            child: Row(
              children: [
                Text(
                  street.toUpperCase(),
                  style: AppTypography.ibm(
                    color: AppColors.limeGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${actions.length})',
                  style: AppTypography.ibm(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textDisabled,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...actions.map((action) => _buildActionItem(action)),
      ],
    );
  }

  Widget _buildActionItem(Map<String, dynamic> action) {
    final seat = action['player'] as int?;
    final actionType = action['action'] as String? ?? 'unknown';
    final amount = (action['amount'] as num?)?.toDouble();
    final playerName = action['playerName'] as String?;

    final isMe = seat == widget.seatNumber;
    final displayName = isMe ? 'You' : (playerName ?? 'Seat $seat');

    Color actionColor;
    switch (actionType.toLowerCase()) {
      case 'fold':
        actionColor = AppColors.errorRed;
        break;
      case 'check':
        actionColor = AppColors.textDisabled;
        break;
      case 'call':
        actionColor = AppColors.limeGreen;
        break;
      case 'bet':
      case 'raise':
        actionColor = const Color(0xFFFFA726);
        break;
      case 'all-in':
        actionColor = AppColors.buttonPrimary;
        break;
      default:
        actionColor = AppColors.textDisabled;
    }

    String actionText = '$displayName ${actionType.toUpperCase()}';
    if (amount != null && amount > 0) {
      actionText += ' ${_formatAmount(amount)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (isMe)
            Container(
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Text(
              actionText,
              style: AppTypography.ibm(
                color: isMe ? Colors.white : const Color(0xFFB3B4B6),
                fontSize: 13,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            actionType.toUpperCase(),
            style: AppTypography.ibm(
              color: actionColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── NOTES ───────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.separatorDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).playerSessionHandNotesLabel,
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.limeGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _handNotes = value),
            onEditingComplete: () => _savePlayerData(),
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 1.44,
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).playerSessionNotesHint,
              hintStyle: AppTypography.ibm(
                fontSize: 15,
                color: AppColors.textDisabled,
              ),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.infoCardDateText, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.infoCardDateText, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.buttonPrimary, width: 1),
              ),
            ),
            maxLines: 3,
            minLines: 1,
          ),
        ],
      ),
    );
  }

  // ─── TAGS ────────────────────────────────────────────────────────

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.separatorDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAGS',
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.limeGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((tag) => _buildTagChip(tag)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _handTags.contains(tag);

    return GestureDetector(
      onTap: () => _toggleTag(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.buttonPrimary.withValues(alpha: 0.15)
              : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          border: Border.all(
            color: isSelected
                ? AppColors.buttonPrimary
                : AppColors.separatorDark,
          ),
        ),
        child: Text(
          tag,
          style: AppTypography.ibm(
            color: isSelected ? AppColors.buttonPrimary : AppColors.textDisabled,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ─── HAND HISTORY ────────────────────────────────────────────────

  Widget _buildHandHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.separatorDark),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isHistoryExpanded = !_isHistoryExpanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.textDisabled, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Hand History',
                        style: AppTypography.ibm(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_handHistory.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.buttonPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                          ),
                          child: Text(
                            '${_handHistory.length}',
                            style: AppTypography.ibm(
                              color: AppColors.buttonPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Icon(
                    _isHistoryExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
          if (_isHistoryExpanded && _handHistory.isNotEmpty) ...[
            Container(height: 1, color: AppColors.separatorDark),
            ..._handHistory.map((hand) => _buildHistoryItem(hand)),
          ],
          if (_isHistoryExpanded && _handHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No completed hands yet',
                style: AppTypography.ibm(
                  color: AppColors.textDisabled,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> hand) {
    final handNumber = hand['handNumber'] as int? ?? 0;
    final winnerId = hand['winnerId'] as int?;
    final pot = (hand['potAmount'] as num?)?.toDouble() ?? 0;
    final isWinner = winnerId == widget.seatNumber;
    final playerTags = (hand['playerTags'] as List?)?.cast<String>() ?? [];
    final playerHoleCards = hand['playerHoleCards'] as Map<String, dynamic>?;
    final hasHoleCards = playerHoleCards != null &&
        playerHoleCards['card1'] != null &&
        playerHoleCards['card2'] != null;

    final boardCardsData = hand['boardCards'] as Map<String, dynamic>?;
    final List<String> boardCards = [];
    if (boardCardsData != null) {
      final flop = boardCardsData['flop'] as List<dynamic>?;
      if (flop != null) boardCards.addAll(flop.cast<String>());
      final turn = boardCardsData['turn'] as String?;
      if (turn != null && turn.isNotEmpty) boardCards.add(turn);
      final river = boardCardsData['river'] as String?;
      if (river != null && river.isNotEmpty) boardCards.add(river);
    }

    return GestureDetector(
      onTap: () => _showEditHandDialog(hand),
      onLongPress: () => _navigateToHandDetails(hand),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.separatorDark, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Hand number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isWinner
                    ? AppColors.limeGreen.withValues(alpha: 0.15)
                    : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              ),
              child: Center(
                child: Text(
                  '#$handNumber',
                  style: AppTypography.ibm(
                    color: isWinner ? AppColors.limeGreen : AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Result
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWinner ? 'Won ${_formatAmount(pot)}' : 'Lost',
                    style: AppTypography.ibm(
                      color: isWinner ? AppColors.limeGreen : AppColors.textDisabled,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (playerTags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: playerTags
                          .map((tag) => Text(
                                tag,
                                style: AppTypography.ibm(
                                  color: AppColors.buttonPrimary,
                                  fontSize: 10,
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
            // Board cards (compact)
            if (boardCards.isNotEmpty) ...[
              _buildCompactBoardCards(boardCards),
              const SizedBox(width: 8),
            ],
            // Edit indicator / hole cards status
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasHoleCards ? Icons.style_rounded : Icons.edit_rounded,
                  color: hasHoleCards ? AppColors.buttonPrimary : AppColors.textDisabled,
                  size: 18,
                ),
                if (hasHoleCards)
                  Text(
                    '${playerHoleCards['card1']}${playerHoleCards['card2']}',
                    style: AppTypography.ibm(
                      color: AppColors.textDisabled,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditHandDialog(Map<String, dynamic> hand) async {
    final handNumber = hand['handNumber'] as int? ?? 0;
    final handId = hand['id'] as String?;

    if (handId == null || _session == null) return;

    String? card1;
    String? card2;
    String notes = '';
    List<String> tags = [];

    final playerHoleCards = hand['playerHoleCards'] as Map<String, dynamic>?;
    if (playerHoleCards != null) {
      card1 = playerHoleCards['card1'] as String?;
      card2 = playerHoleCards['card2'] as String?;
    }
    notes = (hand['playerNotes'] as String?) ?? '';
    tags = (hand['playerTags'] as List?)?.cast<String>() ?? [];

    final odPlayerId = AuthService.userId;
    if (odPlayerId != null) {
      try {
        final playerData = await DealerService.getPlayerHandData(
          sessionId: _session!.id,
          handId: handId,
          odPlayerId: odPlayerId,
        );
        if (playerData != null) {
          final holeCards = playerData['holeCards'] as Map<String, dynamic>?;
          if (holeCards != null) {
            card1 = holeCards['card1'] as String?;
            card2 = holeCards['card2'] as String?;
          }
          if (playerData['notes'] != null) {
            notes = playerData['notes'] as String;
          }
          if (playerData['tags'] != null) {
            tags = (playerData['tags'] as List).cast<String>();
          }
        }
      } catch (e) {
        debugPrint('Error fetching player hand data: $e');
      }
    }

    final usedCards = <String>{};
    final boardCardsData = hand['boardCards'] as Map<String, dynamic>?;
    if (boardCardsData != null) {
      final flop = boardCardsData['flop'] as List?;
      if (flop != null) usedCards.addAll(flop.cast<String>());
      final turn = boardCardsData['turn'] as String?;
      if (turn != null) usedCards.add(turn);
      final river = boardCardsData['river'] as String?;
      if (river != null) usedCards.add(river);
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditHandBottomSheet(
        handNumber: handNumber,
        handId: handId,
        sessionId: _session!.id,
        initialCard1: card1,
        initialCard2: card2,
        initialNotes: notes,
        initialTags: tags,
        usedCards: usedCards,
        availableTags: _availableTags,
        onSaved: () {
          _loadHandHistory();
        },
        onViewDetails: () {
          Navigator.pop(context);
          _navigateToHandDetails(hand);
        },
      ),
    );
  }

  Future<void> _loadHandHistory() async {
    if (_session == null) return;

    try {
      final hands = await DealerService.getSessionHands(_session!.id);
      final completedHands = hands
          .where((h) => h['endTime'] != null)
          .toList()
        ..sort((a, b) => (b['handNumber'] as int? ?? 0)
            .compareTo(a['handNumber'] as int? ?? 0));

      if (mounted) {
        setState(() {
          _handHistory = completedHands.take(20).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading hand history: $e');
    }
  }

  Widget _buildCompactBoardCards(List<String> cards) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        final hasGap = index == 3 || index == 4;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasGap) const SizedBox(width: 2),
            _buildMiniCard(card),
            if (index < cards.length - 1) const SizedBox(width: 2),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMiniCard(String card) {
    final isRed = card.contains('♥') || card.contains('♦');
    return Container(
      width: 18,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.textDisabled, width: 0.5),
      ),
      child: Center(
        child: Text(
          card,
          style: TextStyle(
            color: isRed ? Colors.red : Colors.black,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToHandDetails(Map<String, dynamic> hand) async {
    final handWithPlayerData = Map<String, dynamic>.from(hand);

    _convertTimestamps(handWithPlayerData);

    final playerHoleCards = hand['playerHoleCards'] as Map<String, dynamic>?;
    final handId = hand['id'] as String?;

    final hasValidHoleCards = playerHoleCards != null &&
        playerHoleCards['card1'] != null &&
        playerHoleCards['card2'] != null;

    if (!hasValidHoleCards && _session != null && handId != null) {
      final odPlayerId = AuthService.userId;
      if (odPlayerId != null) {
        try {
          final playerData = await DealerService.getPlayerHandData(
            sessionId: _session!.id,
            handId: handId,
            odPlayerId: odPlayerId,
          );
          if (playerData != null) {
            final holeCards = playerData['holeCards'] as Map<String, dynamic>?;
            if (holeCards != null &&
                holeCards['card1'] != null &&
                holeCards['card2'] != null) {
              handWithPlayerData['ourHoleCards'] = holeCards;
            }
            if (playerData['notes'] != null) {
              handWithPlayerData['notes'] = playerData['notes'];
            }
            if (playerData['tags'] != null) {
              handWithPlayerData['tags'] = playerData['tags'];
            }
          }
        } catch (e) {
          debugPrint('Error fetching player hand data: $e');
        }
      }
    } else if (hasValidHoleCards) {
      handWithPlayerData['ourHoleCards'] = playerHoleCards;
    }

    if (hand['playerNotes'] != null && handWithPlayerData['notes'] == null) {
      handWithPlayerData['notes'] = hand['playerNotes'];
    }
    if (hand['playerTags'] != null && handWithPlayerData['tags'] == null) {
      handWithPlayerData['tags'] = hand['playerTags'];
    }

    if (!mounted) return;

    final hands = List<Map<String, dynamic>>.from(_handHistory);
    final index = hands.indexWhere((h) => h['id'] == handWithPlayerData['id']);
    if (index >= 0) hands[index] = handWithPlayerData;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsPageView(
          hands: hands,
          initialIndex: index < 0 ? 0 : index,
          ourSeat: widget.seatNumber,
        ),
      ),
    );
  }

  void _convertTimestamps(Map<String, dynamic> data) {
    for (final key in data.keys.toList()) {
      final value = data[key];
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        _convertTimestamps(value);
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Timestamp) {
            value[i] = (value[i] as Timestamp).toDate().toIso8601String();
          } else if (value[i] is Map<String, dynamic>) {
            _convertTimestamps(value[i]);
          }
        }
      }
    }
  }

  // ─── PAUSE OVERLAY ───────────────────────────────────────────────

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: 72,
              color: const Color(0xFFFFA726).withValues(alpha: 0.8),
            ),
            const SizedBox(height: 24),
            Text(
              'Dealer Change',
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for new dealer to take over...',
              style: AppTypography.ibm(
                color: AppColors.textMint,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFA726),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EDIT HAND BOTTOM SHEET ──────────────────────────────────────

class _EditHandBottomSheet extends StatefulWidget {
  final int handNumber;
  final String handId;
  final String sessionId;
  final String? initialCard1;
  final String? initialCard2;
  final String initialNotes;
  final List<String> initialTags;
  final Set<String> usedCards;
  final List<String> availableTags;
  final VoidCallback onSaved;
  final VoidCallback onViewDetails;

  const _EditHandBottomSheet({
    required this.handNumber,
    required this.handId,
    required this.sessionId,
    this.initialCard1,
    this.initialCard2,
    required this.initialNotes,
    required this.initialTags,
    required this.usedCards,
    required this.availableTags,
    required this.onSaved,
    required this.onViewDetails,
  });

  @override
  State<_EditHandBottomSheet> createState() => _EditHandBottomSheetState();
}

class _EditHandBottomSheetState extends State<_EditHandBottomSheet> {
  late String? _card1;
  late String? _card2;
  late TextEditingController _notesController;
  late List<String> _selectedTags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _card1 = widget.initialCard1;
    _card2 = widget.initialCard2;
    _notesController = TextEditingController(text: widget.initialNotes);
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final odPlayerId = AuthService.userId;
      if (odPlayerId == null) throw 'Not authenticated';

      await DealerService.savePlayerHandData(
        sessionId: widget.sessionId,
        handId: widget.handId,
        odPlayerId: odPlayerId,
        card1: _card1,
        card2: _card2,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hand #${widget.handNumber} updated',
              style: AppTypography.ibm(color: Colors.white),
            ),
            backgroundColor: AppColors.limeGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving: $e',
              style: AppTypography.ibm(color: Colors.white),
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editHoleCards() async {
    final result = await showDialog<HoleCards>(
      context: context,
      builder: (context) => HoleCardsDialog(
        existingCards: (_card1 != null && _card2 != null)
            ? HoleCards(card1: _card1!, card2: _card2!)
            : null,
        usedCards: widget.usedCards,
        title: AppLocalizations.of(context).playerSessionYourHoleCards,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _card1 = result.card1;
        _card2 = result.card2;
      });
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCards = _card1 != null && _card2 != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDecorations.radius20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textDisabled,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Row(
                children: [
                  Text(
                    'Edit Hand #${widget.handNumber}',
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onViewDetails,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_rounded, size: 16, color: AppColors.buttonPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'View Details',
                          style: AppTypography.ibm(
                            color: AppColors.buttonPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hole Cards
              Text(
                'HOLE CARDS',
                style: AppTypography.ibm(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.limeGreen,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _editHoleCards,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    border: Border.all(
                      color: hasCards
                          ? AppColors.buttonPrimary.withValues(alpha: 0.3)
                          : AppColors.separatorDark,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasCards) ...[
                        _buildCardDisplay(_card1!),
                        const SizedBox(width: 8),
                        _buildCardDisplay(_card2!),
                      ] else ...[
                        const Icon(Icons.add_rounded, color: AppColors.textDisabled, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to add hole cards',
                          style: AppTypography.ibm(
                            color: AppColors.textDisabled,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              Text(
                'NOTES',
                style: AppTypography.ibm(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.limeGreen,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: AppTypography.ibm(
                  fontSize: 15,
                  color: Colors.white,
                  height: 1.44,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).playerSessionNotesHint,
                  hintStyle: AppTypography.ibm(
                    fontSize: 15,
                    color: AppColors.textDisabled,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: const BorderSide(color: AppColors.infoCardDateText, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: const BorderSide(color: AppColors.infoCardDateText, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: const BorderSide(color: AppColors.buttonPrimary, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tags
              Text(
                'TAGS',
                style: AppTypography.ibm(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.limeGreen,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => _toggleTag(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.buttonPrimary.withValues(alpha: 0.15)
                            : AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.buttonPrimary
                              : AppColors.separatorDark,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.ibm(
                          color: isSelected
                              ? AppColors.buttonPrimary
                              : AppColors.textDisabled,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save button
              GestureDetector(
                onTap: _isSaving ? null : _saveChanges,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isSaving
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: AppTypography.ibm(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              letterSpacing: -0.43,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardDisplay(String card) {
    final isRed = card.contains('♥') || card.contains('♦');
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card,
          style: TextStyle(
            color: isRed ? Colors.red : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
