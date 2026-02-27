import 'dart:async';
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
import 'member_table_view_screen.dart';

/// Screen for members to view all tables in a multi-table event
/// Shows availability across all tables and allows joining shared waitlist
class MemberEventTablesScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;

  const MemberEventTablesScreen({
    Key? key,
    required this.club,
    required this.event,
  }) : super(key: key);

  @override
  State<MemberEventTablesScreen> createState() => _MemberEventTablesScreenState();
}

class _MemberEventTablesScreenState extends State<MemberEventTablesScreen> {
  List<_TableData> _tables = [];
  WaitlistEntry? _userWaitlistEntry;
  int? _waitlistPosition;
  int _totalWaitlistCount = 0;
  bool _isLoading = true;
  bool _isJoiningWaitlist = false;
  bool _isLeavingWaitlist = false;

  final Map<String, StreamSubscription> _seatSubscriptions = {};
  StreamSubscription? _waitlistSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupListeners();
  }

  @override
  void dispose() {
    for (final sub in _seatSubscriptions.values) {
      sub.cancel();
    }
    _waitlistSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tables = <_TableData>[];

      for (final tableId in widget.event.tableIds) {
        final table = await TableService.getTable(widget.club.id, tableId);
        if (table != null) {
          tables.add(_TableData(
            table: table,
            seats: {},
          ));
        }
      }

      // Sort by table number
      tables.sort((a, b) => a.table.tableNumber.compareTo(b.table.tableNumber));

      // Get waitlist info
      final entry = await WaitlistService.getUserEntry(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );
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
          _tables = tables;
          _userWaitlistEntry = entry;
          _waitlistPosition = position;
          _totalWaitlistCount = count;
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
    // Watch seats for each table
    for (final tableId in widget.event.tableIds) {
      _seatSubscriptions[tableId] = SeatService.watchTableSeats(
        clubId: widget.club.id,
        tableId: tableId,
      ).listen((seats) {
        if (mounted) {
          setState(() {
            final index = _tables.indexWhere((t) => t.table.id == tableId);
            if (index != -1) {
              _tables[index] = _TableData(
                table: _tables[index].table,
                seats: seats,
              );
            }
          });
        }
      });
    }

    // Watch user's waitlist entry
    _waitlistSubscription = WaitlistService.watchUserEntry(
      clubId: widget.club.id,
      eventId: widget.event.id,
    ).listen((entry) async {
      if (mounted) {
        int? position;
        int count = 0;
        if (entry != null) {
          position = await WaitlistService.getPosition(
            clubId: widget.club.id,
            eventId: widget.event.id,
          );
          count = await WaitlistService.getWaitlistCount(
            clubId: widget.club.id,
            eventId: widget.event.id,
          );
        }
        if (mounted) {
          setState(() {
            _userWaitlistEntry = entry;
            _waitlistPosition = position;
            _totalWaitlistCount = count;
          });
        }
      }
    });
  }

  int get _totalOccupied => _tables.fold(
    0,
    (sum, t) => sum + t.seats.values.where((s) => s.isOccupied).length,
  );

  int get _totalOpen {
    int open = 0;
    for (final tableData in _tables) {
      for (var i = 1; i <= 9; i++) {
        final seat = tableData.seats[i];
        if (seat == null || seat.isEmpty) {
          open++;
        }
      }
    }
    return open;
  }

  bool get _hasOpenSeats => _totalOpen > 0;

  Future<void> _joinWaitlist() async {
    setState(() => _isJoiningWaitlist = true);
    try {
      final entry = await WaitlistService.joinWaitlist(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );

      if (mounted) {
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
          _isJoiningWaitlist = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined waitlist at position #$position'),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoiningWaitlist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join waitlist: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveWaitlist() async {
    setState(() => _isLeavingWaitlist = true);
    try {
      await WaitlistService.leaveWaitlistByUser(
        clubId: widget.club.id,
        eventId: widget.event.id,
      );

      if (mounted) {
        setState(() {
          _userWaitlistEntry = null;
          _waitlistPosition = null;
          _isLeavingWaitlist = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left the waitlist'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLeavingWaitlist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave waitlist: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
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
                  _buildTopBar(),

                  // Tables grid
                  Expanded(
                    child: _buildTablesGrid(),
                  ),

                  // Waitlist section
                  _buildWaitlistSection(),
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

          // Event name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_tables.length} tables  •  $_totalOccupied seated  •  $_totalOpen open',
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

  Widget _buildTablesGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: _tables.length,
        itemBuilder: (context, index) => _buildTableCard(_tables[index]),
      ),
    );
  }

  Widget _buildTableCard(_TableData tableData) {
    final occupied = tableData.seats.values.where((s) => s.isOccupied).length;
    final pending = tableData.seats.values.where((s) => s.isPending).length;
    int open = 0;
    for (var i = 1; i <= 9; i++) {
      final seat = tableData.seats[i];
      if (seat == null || seat.isEmpty) {
        open++;
      }
    }
    final hasOpenSeats = open > 0;

    return GestureDetector(
      onTap: () => _navigateToTable(tableData.table),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasOpenSeats
                ? PokerFriendColors.green.withOpacity(0.3)
                : const Color(0xFF2A2A2E),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mini table visualization
            Container(
              width: 80,
              height: 50,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFF0F6B33), Color(0xFF0A4A24)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFF2A2A2E), width: 2),
              ),
              child: Center(
                child: Text(
                  '${tableData.table.tableNumber}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Table name
            Text(
              tableData.table.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Seat stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatBadge('$occupied', PokerFriendColors.green, Icons.person),
                const SizedBox(width: 8),
                if (pending > 0) ...[
                  _buildStatBadge('$pending', const Color(0xFFF59E0B), Icons.hourglass_empty),
                  const SizedBox(width: 8),
                ],
                _buildStatBadge(
                  '$open',
                  hasOpenSeats ? Colors.white : PokerFriendColors.red,
                  Icons.event_seat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistSection() {
    final isInWaitlist = _userWaitlistEntry != null;

    if (isInWaitlist) {
      // Show position and leave button
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PokerFriendColors.purple.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PokerFriendColors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: PokerFriendColors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position #$_waitlistPosition in waitlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_totalWaitlistCount total waiting',
                        style: const TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isLeavingWaitlist ? null : _leaveWaitlist,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: PokerFriendColors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _isLeavingWaitlist
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PokerFriendColors.red,
                          ),
                        )
                      : const Text(
                          'Leave Waitlist',
                          style: TextStyle(
                            color: PokerFriendColors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show join waitlist button (only if there are open seats somewhere)
    if (_hasOpenSeats) {
      return GestureDetector(
        onTap: _isJoiningWaitlist ? null : _joinWaitlist,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PokerFriendColors.purple,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isJoiningWaitlist)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else ...[
                const Icon(Icons.people, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  _totalWaitlistCount > 0
                      ? 'Join Waitlist ($_totalWaitlistCount waiting)'
                      : 'Join Waitlist',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // No open seats
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PokerFriendColors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_busy,
              color: PokerFriendColors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'All tables are full',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTable(PokerTable table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberTableViewScreen(
          club: widget.club,
          event: widget.event,
          tableId: table.id,
        ),
      ),
    );
  }
}

// Helper class for table data
class _TableData {
  final PokerTable table;
  final Map<int, SeatAssignment> seats;

  _TableData({
    required this.table,
    required this.seats,
  });
}
