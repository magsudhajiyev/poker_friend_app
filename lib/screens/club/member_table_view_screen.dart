import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/poker_table.dart';
import '../../models/seat_assignment.dart';
import '../../services/auth_service.dart';
import '../../services/table_service.dart';
import '../../services/seat_service.dart';
import '../../widgets/poker_table_widget.dart';
import '../../design_system/constants/colors.dart';

/// Read-only screen for members to view who's seated at a table.
/// Joining the waitlist is handled exclusively by the grouped cash game
/// screen — there is only one waitlist per stakes and one place to join it.
class MemberTableViewScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;
  final String tableId;

  const MemberTableViewScreen({
    Key? key,
    required this.club,
    required this.event,
    required this.tableId,
  }) : super(key: key);

  @override
  State<MemberTableViewScreen> createState() => _MemberTableViewScreenState();
}

class _MemberTableViewScreenState extends State<MemberTableViewScreen> {
  PokerTable? _table;
  Map<int, SeatAssignment> _seats = {};
  bool _isLoading = true;

  StreamSubscription? _seatSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupListeners();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final table = await TableService.getTable(widget.club.id, widget.tableId);
      if (mounted) {
        setState(() {
          _table = table;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupListeners() {
    _seatSubscription = SeatService.watchTableSeats(
      clubId: widget.club.id,
      tableId: widget.tableId,
    ).listen((seats) {
      if (mounted) {
        setState(() => _seats = seats);
      }
    });
  }

  int get _openSeats {
    int count = 0;
    for (var i = 1; i <= 9; i++) {
      final seat = _seats[i];
      if (seat == null || seat.isEmpty) {
        count++;
      }
    }
    return count;
  }

  int get _occupiedSeats => _seats.values.where((s) => s.isOccupied).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: PokerFriendColors.purple),
              )
            : Column(
                children: [
                  // Top bar
                  _buildTopBar(),

                  // Table area
                  Expanded(
                    child: PokerTableWidget(
                      activeSeatMap: {
                        for (int i = 1; i <= 9; i++)
                          i: (_seats[i]?.isOccupied ?? false) || (_seats[i]?.isPending ?? false),
                      },
                      showDealerButton: false,
                      tableWidthFraction: 0.80,
                      tableHeightFraction: 0.70,
                      seatBuilder: (seatNumber, isActive) => _buildSeat(seatNumber, _seats[seatNumber]),
                      centerContent: Opacity(
                        opacity: 0.15,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.event.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (widget.event.stakes != null)
                              Text(
                                widget.event.stakes!,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 16),

          // Table name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _table?.name ?? AppLocalizations.of(context).memberTableFallback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).memberTableSeatedOpen(_occupiedSeats, _openSeats),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Stakes badge
          if (widget.event.stakes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: PokerFriendColors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.event.stakes!,
                style: const TextStyle(
                  color: PokerFriendColors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildSeat(int seatNumber, SeatAssignment? assignment) {
    final isOccupied = assignment?.isOccupied ?? false;
    final isPending = assignment?.isPending ?? false;
    final playerName = assignment?.playerName ?? '';

    // Golden highlight when the seat belongs to the current user — makes it
    // trivial for the player to spot "which one is me" at a glance.
    final currentUserId = AuthService.userId;
    final isMine = currentUserId != null &&
        assignment?.playerId != null &&
        assignment!.playerId == currentUserId;

    Color bgColor;
    Color borderColor;
    double borderWidth = 2;
    List<BoxShadow>? shadows;

    if (isMine) {
      bgColor = Colors.black;
      borderColor = const Color(0xFFFFC857); // gold
      borderWidth = 3;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFC857).withValues(alpha: 0.55),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];
    } else if (isOccupied) {
      bgColor = Colors.black;
      borderColor = AppColors.buttonPrimary;
      shadows = [
        BoxShadow(
          color: AppColors.buttonPrimary.withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else if (isPending) {
      bgColor = const Color(0xFF2A2A2E);
      borderColor = const Color(0xFFF59E0B);
      shadows = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else {
      bgColor = const Color(0xFF2A2A2E);
      borderColor = AppColors.buttonPrimary.withValues(alpha: 0.3);
      shadows = null;
    }

    return SizedBox(
      width: 80,
      height: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seat circle
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            child: Center(
              child: isOccupied
                  ? Text(
                      _getInitials(playerName.isNotEmpty ? playerName : 'P'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : isPending
                      ? const Icon(Icons.hourglass_empty, color: Color(0xFFF59E0B), size: 18)
                      : Text(
                          '$seatNumber',
                          style: const TextStyle(
                            color: Color(0xFF4A4A4E),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 4),
          // Player name or "Empty"
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              isOccupied || isPending
                  ? playerName.isNotEmpty ? playerName : AppLocalizations.of(context).memberTablePlayer
                  : AppLocalizations.of(context).memberTableEmpty,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isOccupied
                    ? Colors.white
                    : isPending
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF4A4A4E),
                fontSize: 10,
                fontWeight: isOccupied ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '??';
  }
}
