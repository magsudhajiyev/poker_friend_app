import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/club_member.dart';
import '../../models/poker_table.dart';
import '../../models/seat_assignment.dart';
import '../../models/waitlist_entry.dart';
import '../../services/auth_service.dart';
import '../../services/table_service.dart';
import '../../services/seat_service.dart';
import '../../services/club_service.dart';
import '../../services/waitlist_service.dart';
import '../../services/event_service.dart';
import '../../widgets/poker_table_widget.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen elliptic table view for admin seat management
/// Uses the same visual design as seat_setup_screen.dart
class AdminTableManagementScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;
  final String tableId;

  const AdminTableManagementScreen({
    Key? key,
    required this.club,
    required this.event,
    required this.tableId,
  }) : super(key: key);

  @override
  State<AdminTableManagementScreen> createState() =>
      _AdminTableManagementScreenState();
}

class _AdminTableManagementScreenState
    extends State<AdminTableManagementScreen> {
  PokerTable? _table;
  Map<int, SeatAssignment> _seats = {};
  List<WaitlistEntry> _waitlist = [];
  List<ClubMember> _members = [];
  // All tables in this club — used to label "Table N" in the member search
  // sheet when a member is already seated somewhere else.
  List<PokerTable> _clubTables = [];
  // Every currently-joined seat assignment in this club (across all tables).
  // Used to disable already-seated members in the Select Member list.
  List<SeatAssignment> _clubSeatedAssignments = [];
  bool _isLoading = true;

  StreamSubscription? _seatSubscription;
  StreamSubscription? _waitlistSubscription;
  StreamSubscription? _clubSeatsSubscription;

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
    _clubSeatsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        TableService.getTable(widget.club.id, widget.tableId),
        ClubService.getMembers(widget.club.id),
        TableService.getTables(widget.club.id),
      ]);

      if (mounted) {
        setState(() {
          _table = results[0] as PokerTable?;
          _members = results[1] as List<ClubMember>;
          _clubTables = results[2] as List<PokerTable>;
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
    _seatSubscription = SeatService.watchTableSeats(
      clubId: widget.club.id,
      tableId: widget.tableId,
    ).listen((seats) {
      if (mounted) {
        setState(() => _seats = seats);
      }
    });

    _waitlistSubscription = WaitlistService.watchWaitlist(
      clubId: widget.club.id,
      eventId: widget.event.id,
    ).listen((waitlist) {
      if (mounted) {
        setState(() => _waitlist = waitlist);
      }
    });

    _clubSeatsSubscription = SeatService.watchClubSeatedAssignments(
      clubId: widget.club.id,
    ).listen((assignments) {
      if (mounted) {
        setState(() => _clubSeatedAssignments = assignments);
      }
    });
  }

  /// Map of userId → human-readable "Table N · Seat M" for every member who is
  /// currently seated somewhere in this club (including this table). The admin
  /// should not be able to double-book a player at any seat — even another
  /// seat on the same table — because it would create duplicate rankings and
  /// confuse stack tracking.
  Map<String, String> _buildSeatedInfoByUserId() {
    final byTableId = {
      for (final t in _clubTables) t.id: t,
    };
    // Fall back to the table we already have loaded so the label is still
    // accurate even if the club tables fetch is still in flight.
    if (_table != null && !byTableId.containsKey(_table!.id)) {
      byTableId[_table!.id] = _table!;
    }
    final result = <String, String>{};
    for (final a in _clubSeatedAssignments) {
      final playerId = a.playerId;
      if (playerId == null) continue;
      final table = byTableId[a.tableId];
      final tableLabel = table != null ? AppLocalizations.of(context).adminTableTableNumberLabel(table.tableNumber) : AppLocalizations.of(context).adminTableTableFallback;
      result[playerId] = '$tableLabel · Seat ${a.seatNumber}';
    }
    return result;
  }


  @override
  Widget build(BuildContext context) {
    final occupiedCount = _seats.values.where((s) => s.isOccupied).length;
    final openCount = 9 - occupiedCount;

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
                  _buildTopBar(occupiedCount, openCount),

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

                  // Waitlist indicator at bottom
                  if (_waitlist.isNotEmpty) _buildWaitlistBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar(int occupiedCount, int openCount) {
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
                  _table?.name ?? 'Table',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$occupiedCount seated  •  $openCount open',
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

          // Close table button (only show if event has multiple tables)
          if (widget.event.tableIds.length > 1) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _confirmCloseTable,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PokerFriendColors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close, color: PokerFriendColors.red, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCloseTable() async {
    final occupiedCount = _seats.values.where((s) => s.isOccupied).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).adminEventTablesCloseConfirm(_table?.name ?? 'Table'), style: const TextStyle(color: Colors.white)),
        content: Text(
          occupiedCount > 0
              ? AppLocalizations.of(context).adminTableThisWillMoveMsg(occupiedCount)
              : AppLocalizations.of(context).adminTableThisWillRemoveMsg,
          style: const TextStyle(color: Color(0xFF9A9A9A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: Color(0xFF9A9A9A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).adminEventTablesCloseButton, style: const TextStyle(color: PokerFriendColors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _closeTable();
    }
  }

  Future<void> _closeTable() async {
    try {
      final movedCount = await EventService.removeTableFromEvent(
        clubId: widget.club.id,
        eventId: widget.event.id,
        tableId: widget.tableId,
      );

      if (mounted) {
        final tableName = _table?.name ?? AppLocalizations.of(context).adminTableTableFallback;
        final message = movedCount > 0
            ? AppLocalizations.of(context).adminTableClosedWithWaitlistMsg(tableName, movedCount)
            : AppLocalizations.of(context).adminTableClosedMsg(tableName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context); // Go back to multi-table view
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }


  Widget _buildSeat(int seatNumber, SeatAssignment? assignment) {
    final isOccupied = assignment?.isOccupied ?? false;
    final isPending = assignment?.isPending ?? false;
    final playerName = assignment?.playerName ?? '';

    // Golden highlight when the seat belongs to the current user (admins can
    // be seated as players too). Makes the admin's own seat instantly visible.
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
      borderColor = const Color(0xFF89F1EC);
      shadows = [
        BoxShadow(
          color: const Color(0xFF89F1EC).withValues(alpha: 0.3),
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
      borderColor = const Color(0xFF89F1EC).withValues(alpha: 0.3);
      shadows = null;
    }

    return GestureDetector(
      onTap: () => _handleSeatTap(seatNumber, assignment),
      child: SizedBox(
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
                    ? playerName.isNotEmpty ? playerName : AppLocalizations.of(context).clubCashGamePlayer
                    : AppLocalizations.of(context).adminTableEmptyLabel,
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
      ),
    );
  }

  Widget _buildWaitlistBar() {
    return GestureDetector(
      onTap: _showWaitlistSheet,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PokerFriendColors.purple.withOpacity(0.3),
          ),
        ),
        child: Row(
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
                    AppLocalizations.of(context).adminTableWaitlistInCount(_waitlist.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).adminTableWaitlistNextName(_waitlist.first.userDisplayName),
                    style: const TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: PokerFriendColors.purple),
          ],
        ),
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

  // === Seat Tap Handlers ===

  void _handleSeatTap(int seatNumber, SeatAssignment? assignment) {
    if (assignment == null || assignment.isEmpty) {
      _showSeatPlayerSheet(seatNumber);
    } else if (assignment.isPending) {
      _showPendingOptionsDialog(seatNumber, assignment);
    } else if (assignment.isOccupied) {
      _showOccupiedOptionsDialog(seatNumber, assignment);
    }
  }

  void _showSeatPlayerSheet(int seatNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SeatPlayerSheet(
        seatNumber: seatNumber,
        waitlist: _waitlist,
        members: _members,
        seatedInfoByUserId: _buildSeatedInfoByUserId(),
        onSeatFromWaitlist: (entry) => _seatFromWaitlist(entry, seatNumber),
        onSeatMember: (member) => _seatMember(member, seatNumber),
        onAddWalkUp: (name) => _addWalkUpPlayer(name, seatNumber),
      ),
    );
  }

  void _showWaitlistSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WaitlistSheet(
        waitlist: _waitlist,
        eventName: widget.event.name,
        clubId: widget.club.id,
        eventId: widget.event.id,
        onSeatPlayer: (entry) {
          Navigator.pop(context);
          _showSeatFromWaitlistDialog(entry);
        },
        onNotifyPlayer: (entry) async {
          Navigator.pop(context);
          await _notifyNextPlayer();
        },
      ),
    );
  }

  Future<void> _notifyNextPlayer() async {
    try {
      final notified = await WaitlistService.notifyNextInLine(
        clubId: widget.club.id,
        eventId: widget.event.id,
        eventName: widget.event.name,
      );
      if (mounted && notified != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).adminTableNotifiedName(notified.userDisplayName)),
            backgroundColor: PokerFriendColors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _showPendingOptionsDialog(
    int seatNumber,
    SeatAssignment assignment,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          assignment.playerName ?? 'Player',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context).adminTableWaitingForApproval(seatNumber),
          style: const TextStyle(color: Color(0xFF9A9A9A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: Color(0xFF9A9A9A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reject'),
            child: Text(AppLocalizations.of(context).adminTableReject, style: const TextStyle(color: PokerFriendColors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'approve'),
            child: Text(AppLocalizations.of(context).adminTableApprove, style: const TextStyle(color: PokerFriendColors.green)),
          ),
        ],
      ),
    );

    if (action == 'approve') {
      await _approvePendingPlayer(seatNumber);
    } else if (action == 'reject') {
      await _rejectPendingPlayer(seatNumber);
    }
  }

  Future<void> _showOccupiedOptionsDialog(
    int seatNumber,
    SeatAssignment assignment,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          assignment.playerName ?? 'Player',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Text(AppLocalizations.of(context).adminTableSeatNumber(seatNumber), style: const TextStyle(color: Color(0xFF9A9A9A))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: Color(0xFF9A9A9A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'remove'),
            child: Text(AppLocalizations.of(context).adminTableRemove, style: const TextStyle(color: PokerFriendColors.red)),
          ),
        ],
      ),
    );

    if (action == 'remove') {
      await _removePlayer(seatNumber);
    }
  }

  Future<void> _showSeatFromWaitlistDialog(WaitlistEntry entry) async {
    final emptySeats = <int>[];
    for (var i = 1; i <= 9; i++) {
      final seat = _seats[i];
      if (seat == null || seat.isEmpty) {
        emptySeats.add(i);
      }
    }

    if (emptySeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminTableNoEmptySeats), backgroundColor: Colors.orange),
      );
      return;
    }

    final seatNumber = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).adminTableSeatPlayerName(entry.userDisplayName), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).adminTableSelectSeat, style: const TextStyle(color: Color(0xFF9A9A9A))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emptySeats.map((seat) {
                return GestureDetector(
                  onTap: () => Navigator.pop(context, seat),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4A4A4E)),
                    ),
                    child: Center(
                      child: Text(
                        '$seat',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: Color(0xFF9A9A9A))),
          ),
        ],
      ),
    );

    if (seatNumber != null) {
      await _seatFromWaitlist(entry, seatNumber);
    }
  }

  // === Action Methods ===

  /// Clean up the stakes-scoped waitlist after a player is seated at this
  /// table. No-op for tournaments or events without stakes. Safe to call
  /// even when the player was never on the stakes waitlist.
  Future<void> _removeFromStakesWaitlist(String playerId) async {
    final stakes = widget.event.stakes?.trim();
    if (widget.event.gameType != 'cash' || stakes == null || stakes.isEmpty) {
      return;
    }
    if (playerId.startsWith('manual_')) return; // walk-ups can't be on waitlist
    try {
      await WaitlistService.removeUserFromStakesWaitlist(
        clubId: widget.club.id,
        stakesKey: stakesKeyFor(stakes),
        userId: playerId,
      );
    } catch (_) {
      // Cleanup is best-effort; a failure here shouldn't block the seat action.
    }
  }

  Future<void> _seatFromWaitlist(WaitlistEntry entry, int seatNumber) async {
    try {
      await SeatService.seatUserDirectly(
        clubId: widget.club.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
        playerId: entry.userId,
        playerName: entry.userDisplayName,
      );

      await WaitlistService.markSeated(
        clubId: widget.club.id,
        eventId: widget.event.id,
        entryId: entry.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
      );

      // Also clear this user from any stakes-scoped waitlist for these stakes.
      await _removeFromStakesWaitlist(entry.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).adminTablePlayerSeated(entry.userDisplayName)),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _seatMember(ClubMember member, int seatNumber) async {
    try {
      final memberName = member.displayName ?? AppLocalizations.of(context).clubCashGamePlayer;

      // Defensive guard: if the stream was stale and the disabled-row UI slipped,
      // still block double-booking at the write path.
      final existingSeat = _buildSeatedInfoByUserId()[member.userId];
      if (existingSeat != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).adminTableAlreadySeated(memberName, existingSeat)),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await SeatService.seatUserDirectly(
        clubId: widget.club.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
        playerId: member.userId,
        playerName: memberName,
      );

      await _removeFromStakesWaitlist(member.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).adminTablePlayerSeated(memberName)), backgroundColor: PokerFriendColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _addWalkUpPlayer(String name, int seatNumber) async {
    try {
      await SeatService.addManualPlayer(
        clubId: widget.club.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
        playerName: name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).adminTablePlayerSeated(name)), backgroundColor: PokerFriendColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _approvePendingPlayer(int seatNumber) async {
    try {
      final assignment = _seats[seatNumber];
      if (assignment == null) return;

      await SeatService.approveJoin(
        clubId: widget.club.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
      );

      if (assignment.playerId != null) {
        await _removeFromStakesWaitlist(assignment.playerId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).adminTablePlayerApproved(assignment.playerName ?? '')),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _rejectPendingPlayer(int seatNumber) async {
    try {
      await SeatService.rejectJoin(
        clubId: widget.club.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).adminTablePlayerRejected), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _removePlayer(int seatNumber) async {
    try {
      await SeatService.removeSeatOccupant(
        clubId: widget.club.id,
        tableId: widget.tableId,
        seatNumber: seatNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).adminTablePlayerRemoved), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

}

// === Bottom Sheets ===

class _SeatPlayerSheet extends StatelessWidget {
  final int seatNumber;
  final List<WaitlistEntry> waitlist;
  final List<ClubMember> members;
  /// userId → "Table N · Seat M" for every member already seated elsewhere in
  /// this club. Passed down to the member search sheet so the admin can see
  /// (and can't pick) members who would double-book.
  final Map<String, String> seatedInfoByUserId;
  final Function(WaitlistEntry) onSeatFromWaitlist;
  final Function(ClubMember) onSeatMember;
  final Function(String) onAddWalkUp;

  const _SeatPlayerSheet({
    required this.seatNumber,
    required this.waitlist,
    required this.members,
    required this.seatedInfoByUserId,
    required this.onSeatFromWaitlist,
    required this.onSeatMember,
    required this.onAddWalkUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFcb5242).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$seatNumber',
                    style: const TextStyle(
                      color: Color(0xFFcb5242),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).adminTableSeatPlayer,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (waitlist.isNotEmpty) ...[
            _buildOption(
              context: context,
              icon: Icons.people,
              iconColor: PokerFriendColors.purple,
              title: AppLocalizations.of(context).adminTableFromWaitlist,
              subtitle: AppLocalizations.of(context).adminTableWaitlistNextIs(waitlist.first.userDisplayName),
              onTap: () {
                Navigator.pop(context);
                onSeatFromWaitlist(waitlist.first);
              },
            ),
            const SizedBox(height: 12),
          ],

          _buildOption(
            context: context,
            icon: Icons.person_search,
            iconColor: PokerFriendColors.blue,
            title: AppLocalizations.of(context).adminTableClubMember,
            subtitle: AppLocalizations.of(context).adminTableSearchMembers,
            onTap: () => _showMemberSearch(context),
          ),
          const SizedBox(height: 12),

          _buildOption(
            context: context,
            icon: Icons.person_add,
            iconColor: PokerFriendColors.green,
            title: AppLocalizations.of(context).adminTableWalkUpPlayer,
            subtitle: AppLocalizations.of(context).adminTableAddByName,
            onTap: () => _showWalkUpDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A4A4E)),
          ],
        ),
      ),
    );
  }

  void _showMemberSearch(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _MemberSearchSheet(
          members: members,
          seatedInfoByUserId: seatedInfoByUserId,
          onMemberSelected: (member) {
            Navigator.pop(context);
            onSeatMember(member);
          },
        ),
      ),
    );
  }

  void _showWalkUpDialog(BuildContext context) {
    final controller = TextEditingController();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).adminTableWalkUpPlayer, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).adminTablePlayerName,
            hintStyle: const TextStyle(color: Color(0xFF4A4A4E)),
            filled: true,
            fillColor: const Color(0xFF2A2A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: Color(0xFF9A9A9A))),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                onAddWalkUp(name);
              }
            },
            child: Text(AppLocalizations.of(context).clubCashGameAdd, style: const TextStyle(color: PokerFriendColors.green)),
          ),
        ],
      ),
    );
  }
}

class _MemberSearchSheet extends StatefulWidget {
  final List<ClubMember> members;
  final Map<String, String> seatedInfoByUserId;
  final Function(ClubMember) onMemberSelected;

  const _MemberSearchSheet({
    required this.members,
    required this.seatedInfoByUserId,
    required this.onMemberSelected,
  });

  @override
  State<_MemberSearchSheet> createState() => _MemberSearchSheetState();
}

class _MemberSearchSheetState extends State<_MemberSearchSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.members.where((m) {
      final name = m.displayName ?? '';
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Push already-seated members to the bottom so free members are easy to
    // pick.
    filtered.sort((a, b) {
      final aSeated = widget.seatedInfoByUserId.containsKey(a.userId);
      final bSeated = widget.seatedInfoByUserId.containsKey(b.userId);
      if (aSeated == bSeated) return 0;
      return aSeated ? 1 : -1;
    });

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).adminTableSelectMember,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).adminTableSearch,
              hintStyle: const TextStyle(color: Color(0xFF4A4A4E)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4A4A4E)),
              filled: true,
              fillColor: const Color(0xFF1F1F23),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final member = filtered[index];
                final name = member.displayName ?? AppLocalizations.of(context).clubCashGamePlayer;
                final seatedAt = widget.seatedInfoByUserId[member.userId];
                final isSeated = seatedAt != null;
                return Opacity(
                  opacity: isSeated ? 0.45 : 1.0,
                  child: ListTile(
                    onTap: isSeated ? null : () => widget.onMemberSelected(member),
                    enabled: !isSeated,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2A2A2E),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: isSeated
                        ? Text(
                            seatedAt,
                            style: const TextStyle(
                              color: Color(0xFF89F1EC),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                    trailing: isSeated
                        ? const Icon(Icons.event_seat, color: Color(0xFF89F1EC), size: 18)
                        : const Icon(Icons.chevron_right, color: Color(0xFF4A4A4E)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitlistSheet extends StatelessWidget {
  final List<WaitlistEntry> waitlist;
  final String eventName;
  final String clubId;
  final String eventId;
  final Function(WaitlistEntry) onSeatPlayer;
  final Function(WaitlistEntry) onNotifyPlayer;

  const _WaitlistSheet({
    required this.waitlist,
    required this.eventName,
    required this.clubId,
    required this.eventId,
    required this.onSeatPlayer,
    required this.onNotifyPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: PokerFriendColors.purple),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).clubCashGameWaitlistTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PokerFriendColors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${waitlist.length}',
                  style: const TextStyle(color: PokerFriendColors.purple, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(waitlist.length, (index) {
            final entry = waitlist[index];
            final position = index + 1;
            final isNotified = entry.status == WaitlistStatus.notified;
            final isFirstWaiting = position == 1 && !isNotified;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(12),
                border: isNotified
                    ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isNotified
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : isFirstWaiting
                              ? PokerFriendColors.green.withOpacity(0.15)
                              : const Color(0xFF2A2A2E),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isNotified
                          ? const Icon(Icons.notifications_active, color: Color(0xFFF59E0B), size: 16)
                          : Text(
                              '$position',
                              style: TextStyle(
                                color: isFirstWaiting ? PokerFriendColors.green : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.userDisplayName,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        if (isNotified)
                          Text(
                            AppLocalizations.of(context).adminEventTablesNotified,
                            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  // Notify button for first waiting player only (not already notified)
                  if (isFirstWaiting)
                    GestureDetector(
                      onTap: () => onNotifyPlayer(entry),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: PokerFriendColors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppLocalizations.of(context).adminEventTablesNotify,
                          style: const TextStyle(
                            color: PokerFriendColors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Seat button for all players
                  GestureDetector(
                    onTap: () => onSeatPlayer(entry),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: PokerFriendColors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context).adminEventTablesSeat,
                        style: const TextStyle(
                          color: PokerFriendColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
