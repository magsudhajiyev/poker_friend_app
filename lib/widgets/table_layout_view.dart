import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/seat_assignment.dart';
import '../services/seat_service.dart';

/// A visual representation of a poker table with 9 seats
/// Seats are arranged in an oval pattern around the table
class TableLayoutView extends StatefulWidget {
  final String clubId;
  final String tableId;
  final bool isAdminMode;
  final Function(int seatNumber, SeatAssignment? assignment)? onSeatTap;
  final double tableWidth;
  final double tableHeight;

  const TableLayoutView({
    Key? key,
    required this.clubId,
    required this.tableId,
    this.isAdminMode = false,
    this.onSeatTap,
    this.tableWidth = 280,
    this.tableHeight = 180,
  }) : super(key: key);

  @override
  State<TableLayoutView> createState() => _TableLayoutViewState();
}

class _TableLayoutViewState extends State<TableLayoutView> {
  Map<int, SeatAssignment> _seats = {};
  StreamSubscription? _seatSubscription;

  @override
  void initState() {
    super.initState();
    _setupSeatListener();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    super.dispose();
  }

  void _setupSeatListener() {
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
  }

  /// Get seat positions around the oval table
  /// Positions are calculated to distribute 9 seats evenly
  List<Offset> _getSeatPositions(Size tableSize) {
    final centerX = tableSize.width / 2;
    final centerY = tableSize.height / 2;
    final radiusX = tableSize.width / 2 + 40; // Seats outside table
    final radiusY = tableSize.height / 2 + 40;

    // 9 seats distributed around the oval
    // Start from bottom center and go clockwise
    final positions = <Offset>[];
    final seatAngles = [
      math.pi / 2,           // Seat 1: Bottom center
      math.pi / 4,           // Seat 2: Bottom right
      0,                     // Seat 3: Right
      -math.pi / 4,          // Seat 4: Top right
      -math.pi / 2,          // Seat 5: Top center
      -3 * math.pi / 4,      // Seat 6: Top left
      math.pi,               // Seat 7: Left
      3 * math.pi / 4,       // Seat 8: Bottom left
      math.pi * 0.55,        // Seat 9: Between 1 and 8
    ];

    for (final angle in seatAngles) {
      final x = centerX + radiusX * math.cos(angle);
      final y = centerY + radiusY * math.sin(angle);
      positions.add(Offset(x, y));
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final tableSize = Size(widget.tableWidth, widget.tableHeight);
    final positions = _getSeatPositions(tableSize);

    return SizedBox(
      width: tableSize.width + 120, // Extra space for seats
      height: tableSize.height + 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Table background
          Container(
            width: tableSize.width,
            height: tableSize.height,
            decoration: BoxDecoration(
              color: PokerFriendColors.dark4,
              borderRadius: BorderRadius.circular(tableSize.height / 2),
              border: Border.all(
                color: PokerFriendColors.dark6,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'TABLE',
                style: TextStyle(
                  color: PokerFriendColors.dark7,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),

          // Seats
          ...List.generate(9, (index) {
            final seatNumber = index + 1;
            final position = positions[index];
            final assignment = _seats[seatNumber];

            return Positioned(
              left: position.dx - 30 + 60, // Offset for centering
              top: position.dy - 30 + 60,
              child: _buildSeat(seatNumber, assignment),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSeat(int seatNumber, SeatAssignment? assignment) {
    final isPending = assignment?.isPending ?? false;
    final isOccupied = assignment?.isOccupied ?? false;

    Color bgColor;
    Color borderColor;
    Widget content;

    if (isOccupied) {
      bgColor = PokerFriendColors.green.withOpacity(0.2);
      borderColor = PokerFriendColors.green;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getInitials(assignment!.playerName ?? 'P$seatNumber'),
            style: const TextStyle(
              color: PokerFriendColors.green,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (assignment.chipStack != null)
            Text(
              _formatStack(assignment.chipStack!),
              style: TextStyle(
                color: PokerFriendColors.dark11,
                fontSize: 10,
              ),
            ),
        ],
      );
    } else if (isPending) {
      bgColor = PokerFriendColors.yellow.withOpacity(0.2);
      borderColor = PokerFriendColors.yellow;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            color: PokerFriendColors.yellow,
            size: 16,
          ),
          const SizedBox(height: 2),
          Text(
            'Joining',
            style: TextStyle(
              color: PokerFriendColors.yellow,
              fontSize: 9,
            ),
          ),
        ],
      );
    } else {
      bgColor = PokerFriendColors.dark5;
      borderColor = PokerFriendColors.dark7;
      content = Text(
        '$seatNumber',
        style: TextStyle(
          color: PokerFriendColors.dark9,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final seatWidget = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Center(child: content),
    );

    if (widget.isAdminMode && widget.onSeatTap != null) {
      return GestureDetector(
        onTap: () => widget.onSeatTap!(seatNumber, assignment),
        child: seatWidget,
      );
    }

    return seatWidget;
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

  String _formatStack(double stack) {
    if (stack >= 1000000) {
      return '${(stack / 1000000).toStringAsFixed(1)}M';
    } else if (stack >= 1000) {
      return '${(stack / 1000).toStringAsFixed(1)}K';
    }
    return stack.toStringAsFixed(0);
  }
}

/// Summary of seat availability for a table
class TableAvailabilitySummary extends StatelessWidget {
  final int totalSeats;
  final int occupiedSeats;
  final int pendingSeats;

  const TableAvailabilitySummary({
    Key? key,
    this.totalSeats = 9,
    required this.occupiedSeats,
    required this.pendingSeats,
  }) : super(key: key);

  int get openSeats => totalSeats - occupiedSeats - pendingSeats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Open', openSeats, PokerFriendColors.dark11),
          _buildDivider(),
          _buildStat('Occupied', occupiedSeats, PokerFriendColors.green),
          _buildDivider(),
          _buildStat('Joining', pendingSeats, PokerFriendColors.yellow),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: PokerFriendColors.dark9,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: PokerFriendColors.dark5,
    );
  }
}
