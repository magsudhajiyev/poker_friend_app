import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/poker_table.dart';
import '../services/table_service.dart';
import '../services/seat_service.dart';

/// Dialog for selecting a table when event has multiple tables
class TableSelectionDialog extends StatefulWidget {
  final String clubId;
  final List<String> tableIds;
  final bool isAdminView;
  final Function(PokerTable) onTableSelected;

  const TableSelectionDialog({
    Key? key,
    required this.clubId,
    required this.tableIds,
    this.isAdminView = false,
    required this.onTableSelected,
  }) : super(key: key);

  @override
  State<TableSelectionDialog> createState() => _TableSelectionDialogState();
}

class _TableSelectionDialogState extends State<TableSelectionDialog> {
  bool _isLoading = true;
  List<_TableInfo> _tables = [];

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);

    try {
      final tables = <_TableInfo>[];

      for (final tableId in widget.tableIds) {
        final table = await TableService.getTable(widget.clubId, tableId);
        if (table != null) {
          // Get seat info for availability
          final seats = await SeatService.getTableSeats(
            clubId: widget.clubId,
            tableId: tableId,
          );

          int occupied = 0;
          int pending = 0;
          for (final seat in seats.values) {
            if (seat.isOccupied) occupied++;
            if (seat.isPending) pending++;
          }

          tables.add(_TableInfo(
            table: table,
            occupiedSeats: occupied,
            pendingSeats: pending,
            totalSeats: 9,
          ));
        }
      }

      // Sort by table number
      tables.sort((a, b) => a.table.tableNumber.compareTo(b.table.tableNumber));

      if (mounted) {
        setState(() {
          _tables = tables;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tables: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PokerFriendColors.dark2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.table_restaurant,
                  color: PokerFriendColors.purple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Table',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    color: PokerFriendColors.dark9,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.isAdminView
                  ? 'Choose a table to manage'
                  : 'Choose a table to view availability',
              style: TextStyle(
                fontSize: 14,
                color: PokerFriendColors.dark11,
              ),
            ),
            const SizedBox(height: 24),

            // Table list
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: PokerFriendColors.purple,
                  ),
                ),
              )
            else if (_tables.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No tables available',
                    style: TextStyle(
                      color: PokerFriendColors.dark9,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tables.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final info = _tables[index];
                    return _buildTableCard(info);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(_TableInfo info) {
    final openSeats = info.totalSeats - info.occupiedSeats - info.pendingSeats;
    final hasOpenSeats = openSeats > 0;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onTableSelected(info.table);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasOpenSeats
                ? PokerFriendColors.green.withOpacity(0.3)
                : PokerFriendColors.dark5,
          ),
        ),
        child: Row(
          children: [
            // Table icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark5,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${info.table.tableNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Table info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.table.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildSeatBadge(
                        '$openSeats open',
                        hasOpenSeats
                            ? PokerFriendColors.green
                            : PokerFriendColors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${info.occupiedSeats}/9 seated',
                        style: TextStyle(
                          fontSize: 12,
                          color: PokerFriendColors.dark9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: PokerFriendColors.dark9,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Helper class to hold table info with seat counts
class _TableInfo {
  final PokerTable table;
  final int occupiedSeats;
  final int pendingSeats;
  final int totalSeats;

  _TableInfo({
    required this.table,
    required this.occupiedSeats,
    required this.pendingSeats,
    required this.totalSeats,
  });
}
