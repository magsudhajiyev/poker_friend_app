import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/poker_table_widget.dart';
import '../../models/seat_assignment.dart';
import '../../models/dealer_session.dart';
import '../../services/seat_service.dart';
import '../../services/dealer_service.dart';
import '../../services/websocket_service.dart';
import '../../services/auth_service.dart';
import '../../utils/number_formatter.dart';
import '../../design_system/constants/colors.dart';

/// Screen for players to view the live poker session
class LiveSessionScreen extends StatefulWidget {
  final String clubId;
  final String tableId;
  final int seatNumber;
  final String tableName;
  final String clubName;

  const LiveSessionScreen({
    Key? key,
    required this.clubId,
    required this.tableId,
    required this.seatNumber,
    required this.tableName,
    required this.clubName,
  }) : super(key: key);

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final WebSocketService _wsService = WebSocketService.instance;

  // Session state
  Map<int, SeatAssignment> _seats = {};
  List<Map<String, dynamic>> _recentActions = [];
  double _potAmount = 0;
  int? _currentPlayerSeat;
  int _buttonPosition = 1;
  String _currentStreet = 'preflop';
  int _handNumber = 0;
  bool _isHandActive = false;

  // Dealer session info
  DealerSession? _dealerSession;
  String? _currentHandId;

  // Subscriptions
  StreamSubscription? _seatSubscription;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _handSubscription;

  bool _isLoading = true;
  String? _error;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _sessionSubscription?.cancel();
    _handSubscription?.cancel();
    _wsService.leaveTable(widget.tableId);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Load initial seat data
      _seats = await SeatService.getTableSeats(
        clubId: widget.clubId,
        tableId: widget.tableId,
      );

      // Subscribe to seat updates (Firestore real-time)
      _seatSubscription = SeatService.watchTableSeats(
        clubId: widget.clubId,
        tableId: widget.tableId,
      ).listen((seats) {
        if (mounted) {
          setState(() {
            _seats = seats;
          });
        }
      });

      // Subscribe to dealer session updates (Firestore real-time)
      _sessionSubscription = DealerService.watchActiveSessionForTable(
        clubId: widget.clubId,
        tableId: widget.tableId,
      ).listen((session) {
        if (!mounted) return;

        if (session == null && _dealerSession != null && !_sessionEnded) {
          // Session was ended
          _sessionEnded = true;
          _showSessionEnded();
          return;
        }

        if (session != null) {
          final oldHandId = _currentHandId;
          final newHandId = session.currentHandId;

          setState(() {
            _dealerSession = session;
            _currentHandId = newHandId;
          });

          // If hand changed, start watching the new hand
          if (newHandId != oldHandId) {
            _handSubscription?.cancel();
            if (newHandId != null) {
              _watchCurrentHand(session.id, newHandId);
            } else {
              // Hand was completed, show result if we had one
              setState(() {
                _isHandActive = false;
              });
            }
          }
        }
      });

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

  void _watchCurrentHand(String sessionId, String handId) {
    _handSubscription = DealerService.watchCurrentHand(sessionId, handId).listen((handData) {
      if (!mounted || handData == null) return;

      final actions = (handData['actions'] as List<dynamic>?) ?? [];
      final status = handData['status'] as String?;
      final handNumber = handData['handNumber'] as int? ?? 0;
      final buttonPos = handData['buttonPosition'] as int? ?? _buttonPosition;
      final smallBlind = (handData['smallBlind'] as num?)?.toDouble() ?? 1.0;
      final bigBlind = (handData['bigBlind'] as num?)?.toDouble() ?? 2.0;
      final hasBBante = handData['hasBBante'] as bool? ?? false;

      // Calculate pot from actions + blinds
      double calculatedPot = smallBlind + bigBlind;
      if (hasBBante) {
        calculatedPot += bigBlind;
      }

      // Track bets per player to handle raises correctly
      final Map<int, double> playerBets = {};

      // Convert actions and calculate pot
      final recentActions = <Map<String, dynamic>>[];
      for (final a in actions) {
        final action = a as Map<String, dynamic>;
        final actionType = action['action'] as String?;
        final amount = (action['amount'] as num?)?.toDouble();
        final seat = action['player'] as int?;

        recentActions.add({
          'seat_number': seat,
          'action': actionType,
          'amount': amount,
          'player_name': action['playerName'],
        });

        // Calculate pot contribution based on action
        if (seat != null && actionType != null) {
          switch (actionType) {
            case 'call':
              if (amount != null) {
                calculatedPot += amount;
                playerBets[seat] = (playerBets[seat] ?? 0) + amount;
              }
              break;
            case 'bet':
            case 'raise':
              if (amount != null) {
                // Amount is the total bet, calculate the additional contribution
                final previousBet = playerBets[seat] ?? 0;
                final contribution = amount - previousBet;
                if (contribution > 0) {
                  calculatedPot += contribution;
                  playerBets[seat] = amount;
                }
              }
              break;
            case 'all-in':
              if (amount != null) {
                calculatedPot += amount;
                playerBets[seat] = (playerBets[seat] ?? 0) + amount;
              }
              break;
          }
        }
      }

      // Use stored potAmount if hand is completed (it's more accurate)
      final storedPot = (handData['potAmount'] as num?)?.toDouble() ?? 0;
      final finalPot = status == 'completed' ? storedPot : calculatedPot;

      setState(() {
        _recentActions = recentActions.length > 10
            ? recentActions.sublist(recentActions.length - 10)
            : recentActions;
        _potAmount = finalPot;
        _handNumber = handNumber;
        _buttonPosition = buttonPos;
        _isHandActive = status == 'active';

        // Determine current player (simplified - last action's next player)
        if (recentActions.isNotEmpty) {
          final lastAction = recentActions.last;
          final lastSeat = lastAction['seat_number'] as int?;
          if (lastSeat != null) {
            // Simple next player calculation
            final occupiedSeats = _seats.entries
                .where((e) => e.value.isOccupied)
                .map((e) => e.key)
                .toList()
              ..sort();
            if (occupiedSeats.isNotEmpty) {
              final idx = occupiedSeats.indexOf(lastSeat);
              _currentPlayerSeat = occupiedSeats[(idx + 1) % occupiedSeats.length];
            }
          }
        }
      });

      // Check if hand was completed
      if (status == 'completed' && _isHandActive) {
        final winnerId = handData['winnerId'] as int?;
        if (winnerId != null) {
          _showHandResult({
            'winner_seat': winnerId,
            'pot_amount': finalPot,
          });
        }
      }
    });
  }

  void _showHandResult(Map<String, dynamic> data) {
    final winnerSeat = data['winner_seat'];
    final potAmount = data['pot_amount'];
    final l10n = AppLocalizations.of(context);
    final winnerName = _seats[winnerSeat]?.playerName ?? l10n.liveSessionSeat(winnerSeat);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.liveSessionWinnerSummary(winnerName, potAmount.toString())),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSessionEnded() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          l10n.liveSessionSessionEnded,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.liveSessionSessionEndedBody,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(l10n.commonOk),
          ),
        ],
      );
      },
    );
  }

  Future<void> _leaveTable() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          l10n.liveSessionLeaveTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.liveSessionLeaveBody,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.liveSessionLeave),
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
              content: Text(l10n.liveSessionLeaveFailed(e.toString())),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tableName,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.clubName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveTable,
            tooltip: AppLocalizations.of(context).liveSessionLeaveTooltip,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
              child: Text(AppLocalizations.of(context).commonBack),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Pot display
        _buildPotDisplay(),

        // Table visualization
        Expanded(
          flex: 3,
          child: _buildTableView(),
        ),

        // Action feed
        Expanded(
          flex: 2,
          child: _buildActionFeed(),
        ),

        // My seat info
        _buildMySeatInfo(),
      ],
    );
  }

  Widget _buildPotDisplay() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFF161B22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Hand number
          Column(
            children: [
              Text(
                l10n.liveSessionHand,
                style: TextStyle(
                  color: Colors.purple.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _handNumber > 0 ? '#$_handNumber' : '--',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Pot amount
          Column(
            children: [
              Text(
                l10n.liveSessionPot,
                style: TextStyle(
                  color: Colors.amber.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatCompactCurrency(_potAmount),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Status
          Column(
            children: [
              Text(
                l10n.liveSessionStatus,
                style: TextStyle(
                  color: (_isHandActive ? Colors.green : Colors.grey).withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _isHandActive ? l10n.liveSessionLive : l10n.liveSessionWaiting,
                style: TextStyle(
                  color: _isHandActive ? Colors.green : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    return PokerTableWidget(
      activeSeatMap: {
        for (int i = 1; i <= 9; i++)
          i: _seats[i]?.isOccupied ?? false,
      },
      showDealerButton: false,
      tableWidthFraction: 0.80,
      tableHeightFraction: 0.76,
      seatBuilder: (seatNumber, isActive) {
        final assignment = _seats[seatNumber];
        final isOccupied = assignment?.isOccupied ?? false;
        final isMySeat = seatNumber == widget.seatNumber;
        final isCurrentPlayer = seatNumber == _currentPlayerSeat;
        final isButton = seatNumber == _buttonPosition;
        final chipStack = assignment?.chipStack ?? 0;
        return _buildSeat(
          seatNumber: seatNumber,
          playerName: assignment?.playerName,
          isOccupied: isOccupied,
          isMySeat: isMySeat,
          isCurrentPlayer: isCurrentPlayer,
          isButton: isButton,
          chipStack: chipStack,
        );
      },
      centerContent: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCompactCurrency(_potAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          Text(AppLocalizations.of(context).liveSessionPot, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSeat({
    required int seatNumber,
    String? playerName,
    required bool isOccupied,
    required bool isMySeat,
    required bool isCurrentPlayer,
    bool isButton = false,
    double chipStack = 0,
  }) {
    Color bgColor;
    Color borderColor;

    if (!isOccupied) {
      bgColor = const Color(0xFF2A2A2E);
      borderColor = AppColors.buttonPrimary.withValues(alpha: 0.3);
    } else if (isMySeat) {
      bgColor = Colors.black;
      borderColor = Colors.blue;
    } else if (isCurrentPlayer) {
      bgColor = Colors.black;
      borderColor = Colors.amber;
    } else {
      bgColor = Colors.black;
      borderColor = AppColors.buttonPrimary;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: (isMySeat || isCurrentPlayer) ? 3 : 2,
            ),
            boxShadow: isCurrentPlayer
                ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 15)]
                : (isMySeat
                    ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 10)]
                    : null),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                seatNumber.toString(),
                style: TextStyle(
                  color: isOccupied ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOccupied) ...[
                Text(
                  _truncateName(playerName ?? ''),
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
                if (chipStack > 0)
                  Text(
                    formatCompactCurrency(chipStack),
                    style: TextStyle(
                      color: isMySeat ? Colors.lightBlueAccent : Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ],
          ),
        ),
        // Dealer button badge
        if (isButton && isOccupied)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Center(
                child: Text(
                  AppLocalizations.of(context).liveSessionD,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _truncateName(String name) {
    if (name.length <= 6) return name;
    return '${name.substring(0, 5)}..';
  }

  Widget _buildActionFeed() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).liveSessionRecentActions,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: _recentActions.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).liveSessionWaitingForAction,
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentActions.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final action = _recentActions[_recentActions.length - 1 - index];
                      return _buildActionItem(action);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(Map<String, dynamic> action) {
    final seatNumber = action['seat_number'];
    final actionType = action['action'];
    final amount = action['amount'];
    final playerName = _seats[seatNumber]?.playerName ?? AppLocalizations.of(context).liveSessionSeat(seatNumber);

    String actionText = '$playerName $actionType';
    if (amount != null && amount > 0) {
      actionText += ' ${formatCompactCurrency(amount)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        actionText,
        style: TextStyle(
          color: _getActionColor(actionType),
          fontSize: 14,
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'fold':
        return Colors.red.shade300;
      case 'check':
        return Colors.grey.shade400;
      case 'call':
        return Colors.green.shade300;
      case 'bet':
      case 'raise':
        return Colors.amber.shade300;
      case 'all-in':
        return Colors.purple.shade300;
      default:
        return Colors.white70;
    }
  }

  Widget _buildMySeatInfo() {
    final l10n = AppLocalizations.of(context);
    final mySeat = _seats[widget.seatNumber];
    final myStack = mySeat?.chipStack ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade900,
                shape: BoxShape.circle,
              ),
              child: Text(
                widget.seatNumber.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.liveSessionYourSeat,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    myStack > 0 ? l10n.liveSessionStack(formatCompactCurrency(myStack)) : l10n.liveSessionWaitingForDealer,
                    style: TextStyle(
                      color: myStack > 0 ? Colors.greenAccent : Colors.white54,
                      fontSize: 14,
                      fontWeight: myStack > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Live indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _dealerSession != null
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dealerSession != null ? Colors.green : Colors.grey,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _dealerSession != null ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _dealerSession != null ? l10n.liveSessionLive : l10n.liveSessionOffline,
                    style: TextStyle(
                      color: _dealerSession != null ? Colors.green : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
