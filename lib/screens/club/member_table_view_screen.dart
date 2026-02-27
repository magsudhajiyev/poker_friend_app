import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/poker_table.dart';
import '../../models/seat_assignment.dart';
import '../../models/waitlist_entry.dart';
import '../../services/table_service.dart';
import '../../services/seat_service.dart';
import '../../services/waitlist_service.dart';

/// Screen for members to view table availability and join waitlist
/// Uses the same elliptic table design as admin table management
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
  WaitlistEntry? _userWaitlistEntry;
  int? _waitlistPosition;
  int _totalWaitlistCount = 0;
  bool _isLoading = true;
  bool _isJoiningWaitlist = false;
  bool _isLeavingWaitlist = false;

  StreamSubscription? _seatSubscription;
  StreamSubscription? _waitlistSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupListeners();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _waitlistSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final table = await TableService.getTable(widget.club.id, widget.tableId);
      final position = await WaitlistService.getPosition(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );
      final waitlistCount = await WaitlistService.getWaitlistCount(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );

      if (mounted) {
        setState(() {
          _table = table;
          _waitlistPosition = position;
          _totalWaitlistCount = waitlistCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupListeners() {
    // Watch seat changes
    _seatSubscription = SeatService.watchTableSeats(
      clubId: widget.club.id,
      tableId: widget.tableId,
    ).listen((seats) {
      if (mounted) {
        setState(() {
          _seats = seats;
        });
      }
    });

    // Watch user's waitlist entry
    _waitlistSubscription = WaitlistService.watchUserEntry(
      clubId: widget.club.id,
      eventId: widget.event.id,
    ).listen((entry) async {
      if (mounted) {
        // Get updated position
        final position = await WaitlistService.getPosition(
          clubId: widget.club.id,
          eventId: widget.event.id,
        );
        final count = await WaitlistService.getWaitlistCount(
          clubId: widget.club.id,
          eventId: widget.event.id,
        );

        setState(() {
          _userWaitlistEntry = entry;
          _waitlistPosition = position;
          _totalWaitlistCount = count;
        });
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

  bool get _isInWaitlist => _userWaitlistEntry != null;

  Offset _getSeatPosition(int seatNumber, Size tableSize) {
    final double centerX = tableSize.width / 2;
    final double centerY = tableSize.height / 2;
    final double radiusX = (tableSize.width * 0.80) / 2;
    final double radiusY = (tableSize.height * 0.70) / 2;

    // Start at top-left (225°), go clockwise
    final double startAngle = math.pi * 1.25;
    final double angleStep = (2 * math.pi) / 9;
    final double angle = startAngle + (angleStep * (seatNumber - 1));

    final x = centerX + radiusX * math.cos(angle);
    final y = centerY + radiusY * math.sin(angle);

    return Offset(x, y);
  }

  Future<void> _joinWaitlist() async {
    setState(() => _isJoiningWaitlist = true);
    try {
      final entry = await WaitlistService.joinWaitlist(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );

      if (mounted) {
        // Immediately update local state so UI reflects the change
        setState(() {
          _userWaitlistEntry = entry;
          _isJoiningWaitlist = false;
        });

        // Get updated position
        final position = await WaitlistService.getPosition(
          clubId: widget.club.id,
          eventId: widget.event.id,
        );
        final count = await WaitlistService.getWaitlistCount(
          clubId: widget.club.id,
          eventId: widget.event.id,
        );

        if (mounted) {
          setState(() {
            _waitlistPosition = position;
            _totalWaitlistCount = count;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You joined the waitlist!'),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoiningWaitlist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining waitlist: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveWaitlist() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Waitlist?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will lose your position in the queue.',
          style: TextStyle(color: Color(0xFF9A9A9A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9A9A9A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: PokerFriendColors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeavingWaitlist = true);
    try {
      await WaitlistService.leaveWaitlistByUser(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the waitlist'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving waitlist: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLeavingWaitlist = false);
      }
    }
  }

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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            // Table background with felt
                            Center(
                              child: _buildTableSurface(
                                constraints.maxWidth * 0.80,
                                constraints.maxHeight * 0.70,
                              ),
                            ),

                            // Seats around the table
                            ...List.generate(9, (index) {
                              final seatNumber = index + 1;
                              final assignment = _seats[seatNumber];
                              final position = _getSeatPosition(
                                seatNumber,
                                Size(constraints.maxWidth, constraints.maxHeight),
                              );

                              return Positioned(
                                left: position.dx - 40,
                                top: position.dy - 45,
                                child: _buildSeat(seatNumber, assignment),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),

                  // Waitlist section at bottom
                  _buildBottomSection(),
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
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),

          // Table name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _table?.name ?? 'Table',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_occupiedSeats seated  •  $_openSeats open',
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
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

  Widget _buildTableSurface(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              Color(0xFF0F6B33),
              Color(0xFF0D5D2D),
              Color(0xFF0A4A24),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(200),
          border: Border.all(
            color: const Color(0xFF2A2A2E),
            width: 6,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(194),
            border: Border.all(
              color: const Color(0xFF1A1A1E).withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.15,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }

  Widget _buildSeat(int seatNumber, SeatAssignment? assignment) {
    final isOccupied = assignment?.isOccupied ?? false;
    final isPending = assignment?.isPending ?? false;
    final playerName = assignment?.playerName ?? '';

    Color bgColor;
    Color borderColor;
    List<BoxShadow>? shadows;

    if (isOccupied) {
      bgColor = const Color(0xFF2A2A2E);
      borderColor = PokerFriendColors.green;
      shadows = [
        BoxShadow(
          color: PokerFriendColors.green.withOpacity(0.4),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (isPending) {
      bgColor = const Color(0xFF2A2A2E);
      borderColor = const Color(0xFFF59E0B);
      shadows = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else {
      bgColor = const Color(0xFF0A0A0C);
      borderColor = const Color(0xFF1A1A1E);
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
              border: Border.all(color: borderColor, width: 2),
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
                  ? playerName.isNotEmpty ? playerName : 'Player'
                  : 'Empty',
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

  Widget _buildBottomSection() {
    if (_isInWaitlist) {
      return _buildWaitlistStatus();
    } else if (_openSeats == 0) {
      return _buildJoinWaitlistSection();
    } else {
      return _buildOpenSeatsInfo();
    }
  }

  Widget _buildOpenSeatsInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PokerFriendColors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PokerFriendColors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PokerFriendColors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: PokerFriendColors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seats Available!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PokerFriendColors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_openSeats open seats. Ask the dealer to join.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinWaitlistSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_seat,
            color: Color(0xFF4A4A4E),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Table is Full',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join the waitlist to get notified when a seat opens up.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9A9A9A),
            ),
          ),
          if (_totalWaitlistCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$_totalWaitlistCount ${_totalWaitlistCount == 1 ? "person" : "people"} waiting',
              style: const TextStyle(
                fontSize: 12,
                color: PokerFriendColors.purple,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isJoiningWaitlist ? null : _joinWaitlist,
              style: ElevatedButton.styleFrom(
                backgroundColor: PokerFriendColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isJoiningWaitlist
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Join Waitlist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistStatus() {
    final isNotified = _userWaitlistEntry?.wasNotified ?? false;
    final isFirstInLine = _waitlistPosition == 1;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isNotified
            ? PokerFriendColors.green.withOpacity(0.1)
            : PokerFriendColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNotified
              ? PokerFriendColors.green.withOpacity(0.3)
              : PokerFriendColors.purple.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Position indicator
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isNotified
                  ? PokerFriendColors.green.withOpacity(0.2)
                  : PokerFriendColors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isNotified
                  ? const Icon(
                      Icons.notifications_active,
                      color: PokerFriendColors.green,
                      size: 28,
                    )
                  : Text(
                      '#$_waitlistPosition',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: PokerFriendColors.purple,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Status text
          Text(
            isNotified
                ? 'A Seat is Open!'
                : isFirstInLine
                    ? "You're Next!"
                    : 'In Waitlist',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isNotified ? PokerFriendColors.green : Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isNotified
                ? 'Talk to the dealer to claim your seat.'
                : isFirstInLine
                    ? "You'll be notified when a seat opens."
                    : 'Position $_waitlistPosition of $_totalWaitlistCount',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9A9A9A),
            ),
          ),
          const SizedBox(height: 16),

          // Leave waitlist button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLeavingWaitlist ? null : _leaveWaitlist,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9A9A9A),
                side: const BorderSide(color: Color(0xFF3A3A3E)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLeavingWaitlist
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9A9A9A),
                      ),
                    )
                  : const Text('Leave Waitlist', style: TextStyle(fontSize: 14)),
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
