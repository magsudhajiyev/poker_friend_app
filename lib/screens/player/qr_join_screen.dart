import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/qr_seat_data.dart';
import '../../models/poker_table.dart';
import '../../models/club.dart';
import '../../models/seat_assignment.dart';
import '../../services/club_service.dart';
import '../../services/table_service.dart';
import '../../services/seat_service.dart';
import 'live_session_screen.dart';

/// Screen for confirming and joining a poker table seat
class QRJoinScreen extends StatefulWidget {
  final QRSeatData qrData;

  const QRJoinScreen({
    Key? key,
    required this.qrData,
  }) : super(key: key);

  @override
  State<QRJoinScreen> createState() => _QRJoinScreenState();
}

class _QRJoinScreenState extends State<QRJoinScreen> {
  bool _isLoading = true;
  bool _isJoining = false;
  bool _isWaitingForApproval = false;
  String? _error;
  Club? _club;
  PokerTable? _table;
  bool _isSeatOccupied = false;
  StreamSubscription? _seatSubscription;

  @override
  void initState() {
    super.initState();
    _loadTableInfo();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTableInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load club info
      final club = await ClubService.getClub(widget.qrData.clubId);
      if (club == null) {
        throw 'Club not found';
      }

      // Load table info
      final table = await TableService.getTable(
        widget.qrData.clubId,
        widget.qrData.tableId,
      );
      if (table == null) {
        throw 'Table not found';
      }

      // Check if seat is occupied
      final seatAssignment = await SeatService.getSeatAssignment(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      );

      setState(() {
        _club = club;
        _table = table;
        _isSeatOccupied = seatAssignment?.isOccupied ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinSeat() async {
    if (_club == null || _table == null) return;

    setState(() {
      _isJoining = true;
    });

    try {
      // Request to join (pending approval from dealer)
      await SeatService.requestJoinSeat(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      );

      // Now wait for dealer approval
      setState(() {
        _isJoining = false;
        _isWaitingForApproval = true;
      });

      // Watch the seat for status changes
      _seatSubscription = SeatService.watchSeat(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      ).listen((seat) {
        if (!mounted) return;

        if (seat == null || seat.status == SeatStatus.left) {
          // Join was rejected
          setState(() {
            _isWaitingForApproval = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Your join request was declined'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        } else if (seat.status == SeatStatus.joined) {
          // Approved! Navigate to live session
          _seatSubscription?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LiveSessionScreen(
                clubId: widget.qrData.clubId,
                tableId: widget.qrData.tableId,
                seatNumber: widget.qrData.seatNumber,
                tableName: _table!.name,
                clubName: _club!.name,
              ),
            ),
          );
        }
        // If still pending, keep waiting
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _isWaitingForApproval = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join seat: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _cancelJoinRequest() async {
    try {
      await SeatService.leaveSeat(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      );
      _seatSubscription?.cancel();
      if (mounted) {
        setState(() {
          _isWaitingForApproval = false;
        });
      }
    } catch (e) {
      // Ignore errors on cancel
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Join Table'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading table info...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_isWaitingForApproval) {
      return _buildWaitingForApproval();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table illustration
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A5C1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B4513),
                width: 8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Seat ${widget.qrData.seatNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _table?.name ?? 'Table',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Club and table info
          _buildInfoCard(),

          const SizedBox(height: 24),

          // Status indicator
          if (_isSeatOccupied) _buildOccupiedWarning(),

          const SizedBox(height: 24),

          // Join button
          _buildJoinButton(),

          const SizedBox(height: 16),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.business,
            label: 'Club',
            value: _club?.name ?? 'Unknown',
          ),
          const Divider(color: Colors.white12),
          _buildInfoRow(
            icon: Icons.table_restaurant,
            label: 'Table',
            value: _table?.name ?? 'Unknown',
          ),
          const Divider(color: Colors.white12),
          _buildInfoRow(
            icon: Icons.event_seat,
            label: 'Seat',
            value: 'Seat ${widget.qrData.seatNumber}',
          ),
          const Divider(color: Colors.white12),
          _buildInfoRow(
            icon: Icons.circle,
            label: 'Status',
            value: _table?.status == TableStatus.active ? 'Active Game' : 'Waiting',
            valueColor: _table?.status == TableStatus.active
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 24),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupiedWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.orange.shade300,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This seat may already be occupied. Joining will replace the current player.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForApproval() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated waiting indicator
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange, width: 3),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Waiting for Dealer Approval',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your request to join Seat ${widget.qrData.seatNumber} has been sent.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The dealer will set your chip stack and approve your join.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            // Table info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_restaurant, color: Colors.white54),
                  const SizedBox(width: 12),
                  Text(
                    _table?.name ?? 'Table',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Seat ${widget.qrData.seatNumber}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            // Cancel button
            TextButton(
              onPressed: () async {
                await _cancelJoinRequest();
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Cancel Request',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return ElevatedButton(
      onPressed: _isJoining ? null : _joinSeat,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        disabledBackgroundColor: Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: _isJoining
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 28),
                SizedBox(width: 12),
                Text(
                  'Request to Join',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}
