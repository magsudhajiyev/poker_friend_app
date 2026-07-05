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
import '../../services/event_service.dart';
import '../../l10n/app_localizations.dart';
import 'admin_table_management_screen.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';

/// Screen for admin to view all tables in an event with shared waitlist
/// Used when event has multiple tables
class AdminEventTablesScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;

  const AdminEventTablesScreen({
    Key? key,
    required this.club,
    required this.event,
  }) : super(key: key);

  @override
  State<AdminEventTablesScreen> createState() => _AdminEventTablesScreenState();
}

class _AdminEventTablesScreenState extends State<AdminEventTablesScreen> {
  List<_TableData> _tables = [];
  List<WaitlistEntry> _waitlist = [];
  List<PokerTable> _availableTables = [];
  late ClubEvent _event;
  bool _isLoading = true;

  final Map<String, StreamSubscription> _seatSubscriptions = {};
  StreamSubscription? _waitlistSubscription;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
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
      // Reload event to get latest tableIds
      final updatedEvent = await EventService.getEvent(widget.club.id, _event.id);
      if (updatedEvent != null) {
        _event = updatedEvent;
      }

      final tables = <_TableData>[];

      for (final tableId in _event.tableIds) {
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

      // Load available tables (not assigned to this event)
      final allTables = await TableService.getTables(widget.club.id);
      final eventTableIds = _event.tableIds.toSet();
      final available = allTables.where((t) => !eventTableIds.contains(t.id)).toList();
      available.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));

      if (mounted) {
        setState(() {
          _tables = tables;
          _availableTables = available;
          _isLoading = false;
        });

        // Re-setup seat listeners for new tables
        _setupSeatListeners();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupListeners() {
    _setupSeatListeners();

    // Watch waitlist
    _waitlistSubscription = WaitlistService.watchWaitlist(
      clubId: widget.club.id,
      eventId: _event.id,
    ).listen((waitlist) {
      if (mounted) {
        setState(() => _waitlist = waitlist);
      }
    });
  }

  void _setupSeatListeners() {
    // Cancel existing subscriptions
    for (final sub in _seatSubscriptions.values) {
      sub.cancel();
    }
    _seatSubscriptions.clear();

    // Watch seats for each table
    for (final tableId in _event.tableIds) {
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
  }

  Future<void> _showAddTableDialog() async {
    if (_availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminEventTablesNoTables),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedTable = await showDialog<PokerTable>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radiusLg)),
        title: Text(AppLocalizations.of(context).adminEventTablesAddTable, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableTables.length,
            itemBuilder: (context, index) {
              final table = _availableTables[index];
              return ListTile(
                onTap: () => Navigator.pop(context, table),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant3,
                    borderRadius: BorderRadius.circular(AppDecorations.radius10),
                  ),
                  child: Center(
                    child: Text(
                      '${table.tableNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  table.name,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.add, color: PokerFriendColors.green),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );

    if (selectedTable != null) {
      await _addTable(selectedTable);
    }
  }

  Future<void> _addTable(PokerTable table) async {
    try {
      await EventService.addTableToEvent(
        clubId: widget.club.id,
        eventId: _event.id,
        tableId: table.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).adminEventTablesTableAdded(table.name)),
            backgroundColor: PokerFriendColors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
  }

  Future<void> _confirmCloseTable(_TableData tableData) async {
    final occupiedCount = tableData.seats.values.where((s) => s.isOccupied).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radiusLg)),
        title: Text(AppLocalizations.of(context).adminEventTablesCloseConfirm(tableData.table.name), style: const TextStyle(color: Colors.white)),
        content: Text(
          occupiedCount > 0
              ? AppLocalizations.of(context).adminEventTablesCloseWithPlayers(occupiedCount)
              : AppLocalizations.of(context).adminEventTablesCloseEmpty,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel, style: const TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).adminEventTablesCloseButton, style: const TextStyle(color: PokerFriendColors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _closeTable(tableData);
    }
  }

  Future<void> _closeTable(_TableData tableData) async {
    try {
      final movedCount = await EventService.removeTableFromEvent(
        clubId: widget.club.id,
        eventId: _event.id,
        tableId: tableData.table.id,
      );

      if (mounted) {
        final message = movedCount > 0
            ? AppLocalizations.of(context).adminEventTablesClosedWithWaitlist(tableData.table.name, movedCount)
            : AppLocalizations.of(context).adminEventTablesClosed(tableData.table.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonErrorGeneric('$e')), backgroundColor: PokerFriendColors.red),
        );
      }
    }
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
                color: AppColors.surfaceVariant2,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
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
                  AppLocalizations.of(context).adminEventTablesSummary(_tables.length, _totalOccupied, _totalOpen),
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
                borderRadius: BorderRadius.circular(AppDecorations.radius20),
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
          const SizedBox(width: 8),

          // Add table button
          GestureDetector(
            onTap: _showAddTableDialog,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              child: const Icon(Icons.add, color: PokerFriendColors.purple, size: 24),
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
          color: AppColors.surfaceVariant2,
          borderRadius: BorderRadius.circular(AppDecorations.radius20),
          border: Border.all(
            color: hasOpenSeats
                ? PokerFriendColors.green.withOpacity(0.3)
                : AppColors.surfaceVariant3,
          ),
        ),
        child: Stack(
          children: [
            // Close table button (only show if more than 1 table)
            if (_tables.length > 1)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _confirmCloseTable(tableData),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: PokerFriendColors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: PokerFriendColors.red,
                      size: 16,
                    ),
                  ),
                ),
              ),

            // Table content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mini table visualization
                Container(
                  width: 80,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        Color(0xFF224747),
                        Color(0xFF123631),
                        Color(0xFF02261A),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFF161A14), width: 3),
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
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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
    if (_waitlist.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant2,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant3,
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              child: const Icon(
                Icons.people_outline,
                color: Color(0xFF4A4A4E),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).adminEventTablesNoWaitlist,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showWaitlistSheet,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
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
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
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
                    AppLocalizations.of(context).adminEventTablesWaitlistCount(_waitlist.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).adminEventTablesWaitlistNext(_waitlist.first.userDisplayName),
                    style: const TextStyle(
                      color: AppColors.textMuted,
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

  void _showWaitlistSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceVariant1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDecorations.radius20)),
      ),
      builder: (context) => _WaitlistSheet(
        waitlist: _waitlist,
        tables: _tables,
        onSeatPlayer: (entry, tableData) {
          Navigator.pop(context);
          _seatFromWaitlist(entry, tableData);
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
            content: Text(AppLocalizations.of(context).adminEventTablesPlayerNotified(notified.userDisplayName)),
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

  Future<void> _seatFromWaitlist(WaitlistEntry entry, _TableData tableData) async {
    // Find an empty seat
    int? emptySeat;
    for (var i = 1; i <= 9; i++) {
      final seat = tableData.seats[i];
      if (seat == null || seat.isEmpty) {
        emptySeat = i;
        break;
      }
    }

    if (emptySeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminEventTablesNoEmptySeats),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await SeatService.seatUserDirectly(
        clubId: widget.club.id,
        tableId: tableData.table.id,
        seatNumber: emptySeat,
        playerId: entry.userId,
        playerName: entry.userDisplayName,
      );

      await WaitlistService.markSeated(
        clubId: widget.club.id,
        eventId: widget.event.id,
        entryId: entry.id,
        tableId: tableData.table.id,
        seatNumber: emptySeat,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).adminEventTablesPlayerSeated(entry.userDisplayName, tableData.table.name)),
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

  void _navigateToTable(PokerTable table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminTableManagementScreen(
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

// Waitlist bottom sheet
class _WaitlistSheet extends StatelessWidget {
  final List<WaitlistEntry> waitlist;
  final List<_TableData> tables;
  final Function(WaitlistEntry, _TableData) onSeatPlayer;
  final Function(WaitlistEntry) onNotifyPlayer;

  const _WaitlistSheet({
    required this.waitlist,
    required this.tables,
    required this.onSeatPlayer,
    required this.onNotifyPlayer,
  });

  @override
  Widget build(BuildContext context) {
    // Find tables with open seats
    final tablesWithOpenSeats = tables.where((t) {
      for (var i = 1; i <= 9; i++) {
        final seat = t.seats[i];
        if (seat == null || seat.isEmpty) return true;
      }
      return false;
    }).toList();

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
                AppLocalizations.of(context).adminEventTablesWaitlist,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PokerFriendColors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                ),
                child: Text(
                  '${waitlist.length}',
                  style: const TextStyle(color: PokerFriendColors.purple, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Waitlist entries
          ...List.generate(waitlist.length, (index) {
            final entry = waitlist[index];
            final position = index + 1;
            final isNotified = entry.status == WaitlistStatus.notified;
            final isFirstWaiting = position == 1 && !isNotified;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant2,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: isNotified
                    ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  // Position number or notified icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isNotified
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : isFirstWaiting
                              ? PokerFriendColors.green.withOpacity(0.15)
                              : AppColors.surfaceVariant3,
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

                  // Name and status
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

                  // Notify button (for first waiting player only, not already notified)
                  if (isFirstWaiting)
                    GestureDetector(
                      onTap: () => onNotifyPlayer(entry),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: PokerFriendColors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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

                  // Seat button (if tables available)
                  if (tablesWithOpenSeats.isNotEmpty)
                    PopupMenuButton<_TableData>(
                      onSelected: (table) => onSeatPlayer(entry, table),
                      color: AppColors.surfaceVariant3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      itemBuilder: (context) => tablesWithOpenSeats.map((t) {
                        int openCount = 0;
                        for (var i = 1; i <= 9; i++) {
                          if (t.seats[i] == null || t.seats[i]!.isEmpty) openCount++;
                        }
                        return PopupMenuItem<_TableData>(
                          value: t,
                          child: Text(
                            '${t.table.name} ($openCount open)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: PokerFriendColors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context).adminEventTablesSeat,
                              style: const TextStyle(
                                color: PokerFriendColors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: PokerFriendColors.green, size: 18),
                          ],
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
