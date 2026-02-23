import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dealer_session.dart';
import '../../models/hand_state_machine.dart';
import '../../services/seat_service.dart';
import '../../services/dealer_service.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../utils/number_formatter.dart';
import '../../widgets/hole_cards_dialog.dart';
import '../hand_actions_screen.dart';

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

  // Player's seat info
  double _myStack = 0;

  // Hand state from dealer
  int _handNumber = 0;
  double _potAmount = 0;
  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic>? _boardCards;
  bool _isHandActive = false;
  bool _isShowingExitDialog = false;  // Prevent duplicate exit dialogs

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
    _handSubscription?.cancel();
    _seatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Watch seat updates - also detect if player is removed by dealer
      _seatSubscription = SeatService.watchSeat(
        clubId: widget.clubId,
        tableId: widget.tableId,
        seatNumber: widget.seatNumber,
      ).listen((seat) {
        if (!mounted) return;

        if (seat == null || !seat.isOccupied || seat.playerId != AuthService.userId) {
          // Player was removed from the seat by dealer
          _showRemovedFromTableDialog();
          return;
        }

        // Update chip stack
        setState(() {
          _myStack = seat.chipStack ?? 0;
        });
      });

      // Watch dealer session
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
      // Session ended
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

      // On first load OR when session changes, fetch hands from the new session
      if (isFirstLoad || sessionChanged) {
        if (sessionChanged) {
          // Clear old history when switching to a new session
          setState(() {
            _handHistory = [];
            _currentHand = null;
            _actions = [];
            _boardCards = null;
          });
        }
        _loadExistingHands(session.id);
        _loadEventName(session);
      }

      // If hand changed, watch the new hand
      if (newHandId != oldHandId) {
        _handSubscription?.cancel();

        // If old hand was active, add to history (only if not first load)
        if (!isFirstLoad && oldHandId != null && _currentHand != null) {
          _addToHistory(_currentHand!);
        }

        // Reset player input for new hand
        _resetPlayerInput();

        if (newHandId != null) {
          _watchCurrentHand(session.id, newHandId);
        } else {
          // Hand completed, no active hand
          setState(() {
            _isHandActive = false;
          });
        }
      }

      // Handle session status changes
      if (session.status == DealerSessionStatus.ended) {
        _showSessionEndedDialog();
      }
    }
  }

  void _watchCurrentHand(String sessionId, String handId) {
    // Load player's saved data for this hand
    _loadPlayerHandData(sessionId, handId);

    _handSubscription = DealerService.watchCurrentHand(sessionId, handId).listen((handData) {
      if (!mounted || handData == null) return;

      final actions = (handData['actions'] as List<dynamic>?) ?? [];
      final status = handData['status'] as String?;
      final handNumber = handData['handNumber'] as int? ?? 0;
      final boardCards = handData['boardCards'] as Map<String, dynamic>?;

      // Calculate pot from actions
      double pot = _calculatePotFromActions(handData);

      setState(() {
        _currentHand = handData;
        _handNumber = handNumber;
        _potAmount = pot;
        _actions = actions.cast<Map<String, dynamic>>();
        _boardCards = boardCards;
        _isHandActive = status == 'active';
      });

      // If hand completed, show result
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
    final smallBlind = (handData['smallBlind'] as num?)?.toDouble() ?? 1;
    final bigBlind = (handData['bigBlind'] as num?)?.toDouble() ?? 2;
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
    // Add player's annotations
    final annotatedHand = Map<String, dynamic>.from(hand);

    // Only add hole cards if they're valid
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
      // Keep last 20 hands
      if (_handHistory.length > 20) {
        _handHistory = _handHistory.sublist(0, 20);
      }
    });
  }

  /// Load existing completed hands from Firestore
  Future<void> _loadExistingHands(String sessionId) async {
    try {
      final hands = await DealerService.getSessionHands(sessionId);

      // Filter for completed hands only and sort by hand number descending
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
      print('Error loading existing hands: $e');
    }
  }

  /// Load event name from session's event ID
  Future<void> _loadEventName(DealerSession session) async {
    if (session.eventId == null) {
      setState(() {
        _eventName = null;
      });
      return;
    }

    try {
      final event = await EventService.getEvent(session.clubId, session.eventId!);
      if (mounted && event != null) {
        setState(() {
          _eventName = event.name;
        });
      }
    } catch (e) {
      // Silently fail - event name is optional
    }
  }

  void _showSessionEndedDialog() {
    if (_isShowingExitDialog) return;
    _isShowingExitDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Session Ended',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The dealer has ended this session.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRemovedFromTableDialog() {
    if (_isShowingExitDialog) return;
    _isShowingExitDialog = true;

    // Cancel subscriptions to prevent further updates
    _sessionSubscription?.cancel();
    _handSubscription?.cancel();
    _seatSubscription?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Removed from Table',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You have been removed from the table by the dealer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
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
              ? 'You won ${formatCompactCurrency(pot)}!'
              : 'Seat $winnerId wins ${formatCompactCurrency(pot)}',
        ),
        backgroundColor: isWinner ? Colors.green.shade700 : Colors.grey.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _editHoleCards() async {
    final usedCards = <String>{};

    // Add board cards to used set
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
        title: 'Your Hole Cards',
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _myCard1 = result.card1;
        _myCard2 = result.card2;
      });
      // Save to Firestore for persistence
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
    // Save tags to Firestore
    _savePlayerData();
  }

  Future<void> _leaveTable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Leave Table?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this table?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
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
              content: Text('Failed to leave: ${e.toString()}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final dealerName = _session?.dealerName ?? 'Unknown';

    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _eventName ?? 'Table Session',
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 12,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dealerName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Hand #$_handNumber',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _isHandActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _isHandActive ? 'LIVE' : 'WAITING',
                style: TextStyle(
                  fontSize: 10,
                  color: _isHandActive ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.exit_to_app),
          onPressed: _leaveTable,
          tooltip: 'Leave Table',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status bar
              _buildStatusBar(),
              const SizedBox(height: 16),

              // Hole cards
              _buildHoleCardsSection(),
              const SizedBox(height: 16),

              // Board cards
              if (_boardCards != null) ...[
                _buildBoardCardsSection(),
                const SizedBox(height: 16),
              ],

              // Current hand actions
              _buildActionsSection(),
              const SizedBox(height: 16),

              // Notes
              _buildNotesSection(),
              const SizedBox(height: 12),

              // Tags
              _buildTagsSection(),
              const SizedBox(height: 16),

              // Hand history
              _buildHandHistorySection(),
              const SizedBox(height: 80), // Bottom padding for safety
            ],
          ),
        ),

        // Pause overlay
        if (_isPaused) _buildPauseOverlay(),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem('SEAT', '#${widget.seatNumber}', Colors.blue),
          _buildStatusItem('STACK', formatCompactCurrency(_myStack), Colors.green),
          _buildStatusItem('POT', formatCompactCurrency(_potAmount), Colors.amber),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHoleCardsSection() {
    final hasCards = _myCard1 != null && _myCard2 != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: hasCards
            ? Border.all(color: const Color(0xFF5AC95A).withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.style,
                    color: hasCards ? const Color(0xFF5AC95A) : Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Hole Cards',
                    style: TextStyle(
                      color: hasCards ? const Color(0xFF5AC95A) : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _editHoleCards,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5AC95A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasCards ? 'Edit' : 'Add',
                    style: const TextStyle(
                      color: Color(0xFF5AC95A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: hasCards
                ? [
                    _buildCard(_myCard1!),
                    const SizedBox(width: 12),
                    _buildCard(_myCard2!),
                  ]
                : [
                    Text(
                      'Tap "Add" to enter your hole cards',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCardsSection() {
    final flop = (_boardCards?['flop'] as List?)?.cast<String>() ?? [];
    final turn = _boardCards?['turn'] as String?;
    final river = _boardCards?['river'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text(
                'Board',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flop
              ...flop.map((card) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCard(card),
                  )),
              // Turn
              if (turn != null) ...[
                const SizedBox(width: 8),
                _buildCard(turn),
              ],
              // River
              if (river != null) ...[
                const SizedBox(width: 8),
                _buildCard(river),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String card) {
    final suit = card.length > 1 ? card.substring(1) : '';
    final isRed = suit == '♥' || suit == '♦';

    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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

  Widget _buildActionsSection() {
    if (_actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Waiting for action...',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    // Group actions by street
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.white54, size: 18),
                SizedBox(width: 8),
                Text(
                  'Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...actionsByStreet.entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => _buildStreetActions(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildStreetActions(String street, List<Map<String, dynamic>> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0D1117),
          child: Text(
            street.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF5AC95A),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
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
        actionColor = Colors.red.shade300;
        break;
      case 'check':
        actionColor = Colors.grey.shade400;
        break;
      case 'call':
        actionColor = Colors.green.shade300;
        break;
      case 'bet':
      case 'raise':
        actionColor = Colors.amber.shade300;
        break;
      case 'all-in':
        actionColor = Colors.purple.shade300;
        break;
      default:
        actionColor = Colors.white70;
    }

    String actionText = '$displayName ${actionType.toUpperCase()}';
    if (amount != null && amount > 0) {
      actionText += ' ${formatCompactCurrency(amount)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (isMe)
            Container(
              width: 4,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Text(
              actionText,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            actionType.toUpperCase(),
            style: TextStyle(
              color: actionColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.note, color: Colors.white54, size: 18),
              SizedBox(width: 8),
              Text(
                'Hand Notes',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _handNotes = value),
            onEditingComplete: () => _savePlayerData(),
            decoration: InputDecoration(
              hintText: 'Add notes about this hand...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF0D1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 3,
            minLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.label, color: Colors.white54, size: 18),
              SizedBox(width: 8),
              Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBAFF9A).withValues(alpha: 0.2)
              : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBAFF9A).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? const Color(0xFFBAFF9A) : Colors.white54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHandHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _isHistoryExpanded = !_isHistoryExpanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Hand History',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_handHistory.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_handHistory.length}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Icon(
                    _isHistoryExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          // History items
          if (_isHistoryExpanded && _handHistory.isNotEmpty) ...[
            const Divider(color: Color(0xFF0D1117), height: 1),
            ..._handHistory.map((hand) => _buildHistoryItem(hand)),
          ],
          if (_isHistoryExpanded && _handHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No completed hands yet',
                style: TextStyle(color: Colors.white38, fontSize: 13),
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

    // Extract board cards
    final boardCardsData = hand['boardCards'] as Map<String, dynamic>?;
    final List<String> boardCards = [];
    if (boardCardsData != null) {
      final flop = boardCardsData['flop'] as List<dynamic>?;
      if (flop != null) {
        boardCards.addAll(flop.cast<String>());
      }
      final turn = boardCardsData['turn'] as String?;
      if (turn != null && turn.isNotEmpty) {
        boardCards.add(turn);
      }
      final river = boardCardsData['river'] as String?;
      if (river != null && river.isNotEmpty) {
        boardCards.add(river);
      }
    }

    return GestureDetector(
      onTap: () => _showEditHandDialog(hand),
      onLongPress: () => _navigateToHandDetails(hand),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF0D1117), width: 1),
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
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#$handNumber',
                  style: TextStyle(
                    color: isWinner ? Colors.green : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
                    isWinner ? 'Won ${formatCompactCurrency(pot)}' : 'Lost',
                    style: TextStyle(
                      color: isWinner ? Colors.green : Colors.white54,
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
                                style: const TextStyle(
                                  color: Color(0xFFBAFF9A),
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
                  hasHoleCards ? Icons.style : Icons.edit,
                  color: hasHoleCards ? Colors.green : Colors.white38,
                  size: 18,
                ),
                if (hasHoleCards)
                  Text(
                    '${playerHoleCards!['card1']}${playerHoleCards['card2']}',
                    style: const TextStyle(
                      color: Colors.white54,
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

  /// Show dialog to edit hole cards, notes, and tags for a past hand
  Future<void> _showEditHandDialog(Map<String, dynamic> hand) async {
    final handNumber = hand['handNumber'] as int? ?? 0;
    final handId = hand['id'] as String?;

    if (handId == null || _session == null) return;

    // Load existing player data
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

    // Also try to fetch from Firestore in case local cache is stale
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

    // Get board cards for the hole cards dialog
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
          // Reload hand history to reflect changes
          _loadHandHistory();
        },
        onViewDetails: () {
          Navigator.pop(context);
          _navigateToHandDetails(hand);
        },
      ),
    );
  }

  /// Reload hand history from Firestore
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
        // Add small gap after flop (index 2) and turn (index 3)
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
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
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
    // Add player's hole cards to the hand data if they entered them
    final handWithPlayerData = Map<String, dynamic>.from(hand);

    // Convert Firestore Timestamp objects to ISO 8601 strings
    _convertTimestamps(handWithPlayerData);

    // Try to fetch player data from Firestore if not already in hand
    final playerHoleCards = hand['playerHoleCards'] as Map<String, dynamic>?;
    final handId = hand['id'] as String?;

    // Check if we have valid hole cards (not just a map with null values)
    final hasValidHoleCards = playerHoleCards != null &&
        playerHoleCards['card1'] != null &&
        playerHoleCards['card2'] != null;

    if (!hasValidHoleCards && _session != null && handId != null) {
      // Fetch from Firestore
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

    // Add player's notes and tags from local cache if available
    if (hand['playerNotes'] != null && handWithPlayerData['notes'] == null) {
      handWithPlayerData['notes'] = hand['playerNotes'];
    }
    if (hand['playerTags'] != null && handWithPlayerData['tags'] == null) {
      handWithPlayerData['tags'] = hand['playerTags'];
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsScreen(
          hand: handWithPlayerData,
          ourSeat: widget.seatNumber,
        ),
      ),
    );
  }

  /// Convert Firestore Timestamp objects to ISO 8601 strings for compatibility
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

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_horiz,
              size: 80,
              color: Colors.amber.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 24),
            const Text(
              'Dealer Change',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for new dealer to take over...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.amber.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for editing a past hand's hole cards, notes, and tags
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
          const SnackBar(
            content: Text('Hand #${0} updated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
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
        title: 'Your Hole Cards',
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
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Text(
                    'Edit Hand #${widget.handNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onViewDetails,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hole Cards
              const Text(
                'Hole Cards',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _editHoleCards,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D44),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasCards ? Colors.green.withValues(alpha: 0.5) : Colors.white12,
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
                        const Icon(Icons.add, color: Colors.white38, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Tap to add hole cards',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              const Text(
                'Notes',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add notes about this hand...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2D2D44),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tags
              const Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFBAFF9A).withValues(alpha: 0.2)
                            : const Color(0xFF2D2D44),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFBAFF9A)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFBAFF9A)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBAFF9A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
