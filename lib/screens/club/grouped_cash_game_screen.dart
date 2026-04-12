import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/poker_table.dart';
import '../../models/seat_assignment.dart';
import '../../models/waitlist_entry.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/seat_service.dart';
import '../../services/table_service.dart';
import '../../services/waitlist_service.dart';
import 'admin_table_management_screen.dart';
import 'member_table_view_screen.dart';

/// Grouped Cash Game screen — collapses multiple live cash events sharing the
/// same stakes into a single 2-column table grid. Tapping a table card goes
/// straight to the appropriate per-table screen based on [isAdmin].
///
/// Matches Figma node 1213:8244.
class GroupedCashGameScreen extends StatefulWidget {
  final Club club;
  final String stakes; // e.g., "1/2"
  final List<ClubEvent> events; // all live cash events sharing these stakes
  final bool isAdmin;

  const GroupedCashGameScreen({
    Key? key,
    required this.club,
    required this.stakes,
    required this.events,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<GroupedCashGameScreen> createState() => _GroupedCashGameScreenState();
}

class _GroupedCashGameScreenState extends State<GroupedCashGameScreen> {
  String get _stakesKey => stakesKeyFor(widget.stakes);

  List<_GroupedTable> _tables = [];
  WaitlistEntry? _userWaitlistEntry;
  int? _waitlistPosition;
  int _adminWaitlistCount = 0;
  bool _isLoading = true;
  bool _isJoining = false;
  bool _isLeaving = false;
  String? _error;

  final Map<String, StreamSubscription> _seatSubs = {};
  StreamSubscription? _waitlistSub;
  StreamSubscription? _adminWaitlistCountSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupWaitlistListeners();
  }

  @override
  void dispose() {
    for (final s in _seatSubs.values) {
      s.cancel();
    }
    _waitlistSub?.cancel();
    _adminWaitlistCountSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final tables = <_GroupedTable>[];

      // Fetch tables AND their initial seat snapshots first, so the initial
      // render shows correct occupancy. We use a one-shot `getTableSeats` to
      // guarantee the data lands before we paint, then hand off to a stream.
      for (final event in widget.events) {
        for (final tableId in event.tableIds) {
          final table = await TableService.getTable(widget.club.id, tableId);
          if (table == null) continue;
          final seats = await SeatService.getTableSeats(
            clubId: widget.club.id,
            tableId: tableId,
          );
          tables.add(_GroupedTable(
            event: event,
            table: table,
            seats: seats,
          ));
        }
      }
      tables.sort((a, b) => a.table.tableNumber.compareTo(b.table.tableNumber));

      // Waitlist is a member-only feature; admins manage seating directly.
      WaitlistEntry? entry;
      int? position;
      if (!widget.isAdmin) {
        entry = await WaitlistService.getUserStakesEntry(
          clubId: widget.club.id,
          stakesKey: _stakesKey,
        );
        position = await WaitlistService.getStakesWaitlistPosition(
          clubId: widget.club.id,
          stakesKey: _stakesKey,
        );
      }

      if (!mounted) return;
      setState(() {
        _tables = tables;
        _userWaitlistEntry = entry;
        _waitlistPosition = position;
        _isLoading = false;
      });

      // Now that `_tables` is populated, subscribe to real-time seat updates.
      _setupSeatListeners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load tables: $e';
        _isLoading = false;
      });
    }
  }

  /// Subscribe to real-time seat streams for every table currently in
  /// `_tables`. Must be called AFTER `_tables` is populated so the listener
  /// callbacks can find the right index to update.
  void _setupSeatListeners() {
    for (final grouped in _tables) {
      final eventId = grouped.event.id;
      final tableId = grouped.table.id;
      final key = '${eventId}_$tableId';
      if (_seatSubs.containsKey(key)) continue;
      _seatSubs[key] = SeatService.watchTableSeats(
        clubId: widget.club.id,
        tableId: tableId,
      ).listen((seats) {
        if (!mounted) return;
        setState(() {
          final index = _tables.indexWhere(
            (t) => t.event.id == eventId && t.table.id == tableId,
          );
          if (index != -1) {
            _tables[index] = _GroupedTable(
              event: _tables[index].event,
              table: _tables[index].table,
              seats: seats,
            );
          }
        });
      });
    }
  }

  void _setupWaitlistListeners() {
    // Watch current user's stakes-waitlist entry — members only.
    if (!widget.isAdmin) {
      _waitlistSub = WaitlistService.watchUserStakesEntry(
        clubId: widget.club.id,
        stakesKey: _stakesKey,
      ).listen((entry) async {
        if (!mounted) return;
        int? position;
        if (entry != null) {
          position = await WaitlistService.getStakesWaitlistPosition(
            clubId: widget.club.id,
            stakesKey: _stakesKey,
          );
        }
        if (!mounted) return;
        setState(() {
          _userWaitlistEntry = entry;
          _waitlistPosition = position;
        });
      });
    }

    // Watch total waitlist count — admins only, for the "View Waitlist" FAB.
    if (widget.isAdmin) {
      _adminWaitlistCountSub = WaitlistService.watchStakesWaitlist(
        clubId: widget.club.id,
        stakesKey: _stakesKey,
      ).listen((entries) {
        if (!mounted) return;
        setState(() {
          _adminWaitlistCount = entries.length;
        });
      });
    }
  }

  int get _totalOccupied =>
      _tables.fold(0, (sum, t) => sum + t.occupied);

  int get _totalOpen => _tables.fold(0, (sum, t) => sum + t.open);

  /// Whether any table in the group currently has at least one open seat.
  /// Used to short-circuit "Join Waitlist" — if a seat exists, the user
  /// should walk to registration instead of entering the waitlist.
  bool get _anySeatAvailable => _tables.any((t) => t.hasOpenSeat);

  /// Whether the current user is already occupying a seat at any table in
  /// the group. Used to block joining the waitlist — a seated player has
  /// no reason to wait in line.
  bool get _isUserSeated {
    final uid = AuthService.userId;
    if (uid == null) return false;
    for (final t in _tables) {
      for (final seat in t.seats.values) {
        if (seat.isOccupied && seat.playerId == uid) return true;
      }
    }
    return false;
  }

  Future<void> _joinWaitlist() async {
    if (_isJoining) return;

    // Short-circuit: if the user is already seated at one of these tables,
    // joining the waitlist is nonsensical.
    if (_isUserSeated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("You're already seated at a table"),
          backgroundColor: AppColors.mint700,
        ),
      );
      return;
    }

    // Short-circuit: if any table has an open seat, there's no point joining
    // the waitlist — the user should go to registration and take the seat.
    if (_anySeatAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "There's a seat available for you, approach registration",
          ),
          backgroundColor: AppColors.mint700,
        ),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final entry = await WaitlistService.joinStakesWaitlist(
        clubId: widget.club.id,
        stakesKey: _stakesKey,
      );
      final position = await WaitlistService.getStakesWaitlistPosition(
        clubId: widget.club.id,
        stakesKey: _stakesKey,
      );
      if (!mounted) return;
      setState(() {
        _userWaitlistEntry = entry;
        _waitlistPosition = position;
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined waitlist at position #$position'),
          backgroundColor: AppColors.mint700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join waitlist: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _leaveWaitlist() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    try {
      await WaitlistService.leaveStakesWaitlist(
        clubId: widget.club.id,
        stakesKey: _stakesKey,
      );
      if (!mounted) return;
      setState(() {
        _userWaitlistEntry = null;
        _waitlistPosition = null;
        _isLeaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Left the waitlist'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLeaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave waitlist: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _navigateToTable(_GroupedTable t) async {
    if (widget.isAdmin) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminTableManagementScreen(
            club: widget.club,
            event: t.event,
            tableId: t.table.id,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberTableViewScreen(
            club: widget.club,
            event: t.event,
            tableId: t.table.id,
          ),
        ),
      );
    }
    // Table may have been closed/removed while we were away — re-fetch events
    // and rebuild so any removed tables disappear without a manual refresh.
    if (!mounted) return;
    await _refreshAfterAdd();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.backgroundPaper,
      body: Stack(
        children: [
          // Teal glow at top (matches final_standings_screen pattern)
          Positioned(
            top: -250 + topPadding,
            left: -screenWidth * 0.25,
            right: -screenWidth * 0.25,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    const Color(0xFF2E5A59).withOpacity(0.9),
                    const Color(0xFF2E5A59).withOpacity(0.5),
                    const Color(0xFF0D2B2A).withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.buttonPrimary,
                      ),
                    ),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            color: AppColors.textDisabled,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(child: _buildTablesGrid()),
              ],
            ),
          ),

          // Floating action button — members see "Join Waitlist", admins
          // see "View Waitlist" to manage/review the queue.
          if (!_isLoading && _error == null)
            Positioned(
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: _buildWaitlistFab(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF101115),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(18, 13.5),
                painter: _BackArrowPainter(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cash Game ${widget.stakes}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxs),
                Text(
                  '${_tables.length} tables · $_totalOccupied seated · $_totalOpen open',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.47,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          if (widget.isAdmin)
            GestureDetector(
              onTap: _openAddTableSheet,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.buttonPrimary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF02050B),
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openAddTableSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTableSheet(
        club: widget.club,
        stakes: widget.stakes,
        groupEvents: widget.events,
        onTableAdded: _refreshAfterAdd,
      ),
    );
  }

  Future<void> _refreshAfterAdd() async {
    // Re-fetch event docs so we pick up any tableIds that were just appended
    // (or removed via table close). widget.events is immutable, so we mutate
    // the screen's _tables list directly instead.
    try {
      final freshEvents = <ClubEvent>[];
      for (final e in widget.events) {
        final fresh = await EventService.getEvent(widget.club.id, e.id);
        if (fresh != null) freshEvents.add(fresh);
      }
      if (freshEvents.isEmpty) return;

      // Rebuild the full _tables list from the fresh events, fetching each
      // table's current seats up front so the grid renders with correct
      // occupancy immediately.
      final tables = <_GroupedTable>[];
      for (final event in freshEvents) {
        for (final tableId in event.tableIds) {
          final table = await TableService.getTable(widget.club.id, tableId);
          if (table == null) continue;
          final seats = await SeatService.getTableSeats(
            clubId: widget.club.id,
            tableId: tableId,
          );
          tables.add(_GroupedTable(
            event: event,
            table: table,
            seats: seats,
          ));
        }
      }
      tables.sort((a, b) => a.table.tableNumber.compareTo(b.table.tableNumber));

      if (!mounted) return;
      setState(() => _tables = tables);

      // Cancel seat subscriptions for tables that no longer exist in the group
      // (closed/removed while we were on the table screen).
      final liveKeys = tables
          .map((t) => '${t.event.id}_${t.table.id}')
          .toSet();
      final staleKeys = _seatSubs.keys
          .where((k) => !liveKeys.contains(k))
          .toList();
      for (final k in staleKeys) {
        await _seatSubs[k]?.cancel();
        _seatSubs.remove(k);
      }

      // Subscribe to seats for any newly added tables.
      _setupSeatListeners();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh tables: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildTablesGrid() {
    if (_tables.isEmpty) {
      return Center(
        child: Text(
          'No tables in this group',
          style: GoogleFonts.ibmPlexSans(
            color: AppColors.textDisabled,
            fontSize: 14,
          ),
        ),
      );
    }

    // Responsive cards: derive childAspectRatio so the Figma content
    // (24 padding + oval + 10 + label + 10 + pills + 24 padding) fits.
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0 * 2;
    const crossAxisSpacing = 16.0;
    final cardWidth = (screenWidth - horizontalPadding - crossAxisSpacing) / 2;
    // Content below oval: 10 gap + label ~20 + 10 gap + pills ~34 = 74.
    // Plus 48px vertical card padding → reserved = 122.
    // Oval rendered width = innerWidth, rendered height = innerWidth / 1.363.
    const reservedForChromeAndText = 122.0;
    final innerWidth = cardWidth - 48;
    final ovalHeight = innerWidth / 1.363;
    final targetCardHeight = ovalHeight + reservedForChromeAndText;
    final aspectRatio = cardWidth / targetCardHeight;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: _tables.length,
      itemBuilder: (context, index) => _buildTableCard(_tables[index]),
    );
  }

  Widget _buildTableCard(_GroupedTable t) {
    return GestureDetector(
      onTap: () => _navigateToTable(t),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF161A14), width: 1),
        ),
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Oval preserves Figma ratio (136.306:100 ≈ 1.363).
            // Cap by available height minus room for label (~20) + pills
            // (~34) + two 10px gaps = 74, to guarantee no overflow.
            const reservedBelow = 74.0;
            final maxOvalHeight = (constraints.maxHeight - reservedBelow).clamp(0.0, double.infinity);
            final ovalRenderedWidth = (constraints.maxWidth).clamp(0.0, maxOvalHeight * 1.363);
            final ovalRenderedHeight = ovalRenderedWidth / 1.363;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniOvalTable(ovalRenderedWidth, ovalRenderedHeight),
                const SizedBox(height: 10),
                Text(
                  'Table ${t.table.tableNumber}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSeatedPill(t),
                    const SizedBox(width: 10),
                    _buildOpenPill(t),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Mini oval poker table matching Figma node 1213:8660. Figma uses a
  /// 100×136.306 container rotated -90° to render as 136.306×100. We replicate
  /// the same RotatedBox trick, scaling to the given rendered dimensions.
  Widget _buildMiniOvalTable(double renderedWidth, double renderedHeight) {
    // Pre-rotation container matches Figma: width 100, height 136.306.
    // After quarterTurns: 1 rotation, Flutter swaps the box: pre-width
    // becomes post-height, pre-height becomes post-width.
    final preWidth = renderedHeight;
    final preHeight = renderedWidth;

    // Scale Figma's border / inset / label metrics proportionally to the
    // rendered oval height (Figma baseline: 100).
    final scale = renderedHeight / 100.0;
    final outerBorder = 4.459 * scale;
    // Figma inner rect is 87.898×122.293 inside a 100×136.306 outer with a
    // 4.459 border → inset from border edge ≈ 1.62 on each side.
    final innerInset = 1.62 * scale;
    final innerBorder = 1.592 * scale;
    final labelSize = 17 * scale;

    return RotatedBox(
      quarterTurns: 1,
      child: Container(
        width: preWidth,
        height: preHeight,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment.center,
            radius: 0.75,
            colors: [
              Color(0xFF224747),
              Color(0xFF123631),
              Color(0xFF02261A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFF161A14),
            width: outerBorder,
          ),
          borderRadius: BorderRadius.circular(preWidth),
        ),
        child: Padding(
          padding: EdgeInsets.all(innerInset),
          child: Container(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment.center,
                radius: 0.75,
                colors: [
                  Color(0xFF224747),
                  Color(0xFF123631),
                  Color(0xFF02261A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFF12332D),
                width: innerBorder,
              ),
              borderRadius: BorderRadius.circular(preWidth),
            ),
            alignment: Alignment.center,
            child: RotatedBox(
              quarterTurns: -1,
              child: Text(
                widget.stakes,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w500,
                  height: 1.44,
                  color: AppColors.buttonPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeatedPill(_GroupedTable t) {
    final fg = t.isFull ? Colors.white : AppColors.buttonPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: t.isFull ? AppColors.errorRed : AppColors.mint800,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(
            '${t.occupied}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenPill(_GroupedTable t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutral700,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_seat, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${t.open}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistFab() {
    final isAdmin = widget.isAdmin;
    final inWaitlist = _userWaitlistEntry != null;
    final busy = _isJoining || _isLeaving;

    final String label;
    final IconData icon;
    final VoidCallback? onTap;
    if (isAdmin) {
      label = 'View Waitlist';
      icon = Icons.visibility_outlined;
      onTap = _viewWaitlistAsAdmin;
    } else if (inWaitlist) {
      label = 'In waitlist${_waitlistPosition != null ? ' · #$_waitlistPosition' : ''}';
      icon = Icons.check;
      onTap = busy ? null : _confirmLeaveWaitlist;
    } else {
      label = 'Join Waitlist';
      icon = Icons.add;
      onTap = busy ? null : _joinWaitlist;
    }

    return Opacity(
      opacity: busy ? 0.6 : 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(58),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 37, sigmaY: 37),
          child: Material(
            color: AppColors.backgroundSurface.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(58),
              side: const BorderSide(color: Colors.white, width: 1),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(58),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint900,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_adminWaitlistCount',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.buttonPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens a bottom sheet drawer showing the full stakes-scoped waitlist in
  /// FIFO order. Admins can tap the bell next to any entry to notify that
  /// user that a seat is available. Matches the shape/sizing pattern used
  /// by other sheets in the app (e.g. admin_table_management_screen).
  void _viewWaitlistAsAdmin() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminWaitlistSheet(
        clubId: widget.club.id,
        stakesKey: _stakesKey,
        stakesDisplay: widget.stakes,
      ),
    );
  }

  Future<void> _confirmLeaveWaitlist() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSurface,
        title: Text(
          'Leave waitlist?',
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
        ),
        content: Text(
          'You will lose your current position.',
          style: GoogleFonts.ibmPlexSans(color: AppColors.textDisabled),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep',
              style: GoogleFonts.ibmPlexSans(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Leave',
              style: GoogleFonts.ibmPlexSans(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
    if (shouldLeave == true) {
      await _leaveWaitlist();
    }
  }
}

/// A single table within the grouped cash game screen, tagged with its
/// owning [ClubEvent] so the per-table tap can navigate directly.
class _GroupedTable {
  final ClubEvent event;
  final PokerTable table;
  final Map<int, SeatAssignment> seats;

  const _GroupedTable({
    required this.event,
    required this.table,
    required this.seats,
  });

  int get occupied => seats.values.where((s) => s.isOccupied).length;

  int get open {
    var o = 0;
    for (var i = 1; i <= 9; i++) {
      final seat = seats[i];
      if (seat == null || seat.isEmpty) o++;
    }
    return o;
  }

  /// A table is "full" when there are no empty seats available — used to
  /// flip the seated pill to red. Works for tables with fewer than 9 seats.
  bool get isFull => open == 0;

  /// Whether this table has at least one open seat available right now.
  bool get hasOpenSeat => open > 0;
}

/// Back arrow matching Figma node 13:927 — thin horizontal shaft with a
/// small leftward arrowhead, rendered on an 18×13.5 canvas.
class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final midY = size.height / 2;
    // Horizontal shaft from right edge to just past the arrowhead tip.
    canvas.drawLine(
      Offset(size.width, midY),
      Offset(0, midY),
      paint,
    );
    // Arrowhead: two lines from the tip (0, midY) up-right and down-right.
    final headLen = size.height / 2;
    final path = Path()
      ..moveTo(headLen, 0)
      ..lineTo(0, midY)
      ..lineTo(headLen, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Admin-only bottom sheet listing the stakes-scoped waitlist in FIFO order.
/// Matches the standard app drawer pattern (90% height, black bg, 32px top
/// radius, `#262626` border, teal glow shadow, 38×38 circle close button +
/// centered 17px title header). Each row shows the player's #position,
/// display name, and a bell button that sends a "seat available" notification.
class _AdminWaitlistSheet extends StatefulWidget {
  final String clubId;
  final String stakesKey;
  final String stakesDisplay;

  const _AdminWaitlistSheet({
    required this.clubId,
    required this.stakesKey,
    required this.stakesDisplay,
  });

  @override
  State<_AdminWaitlistSheet> createState() => _AdminWaitlistSheetState();
}

class _AdminWaitlistSheetState extends State<_AdminWaitlistSheet> {
  final Set<String> _notifying = <String>{};

  Future<void> _notify(WaitlistEntry entry) async {
    if (_notifying.contains(entry.id)) return;
    setState(() => _notifying.add(entry.id));
    try {
      await WaitlistService.notifyStakesWaitlistEntry(
        clubId: widget.clubId,
        stakesKey: widget.stakesKey,
        entry: entry,
        stakesDisplay: widget.stakesDisplay,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.userDisplayName} has been notified',
            style: GoogleFonts.ibmPlexSans(),
          ),
          backgroundColor: AppColors.mint700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to notify: $e',
            style: GoogleFonts.ibmPlexSans(),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _notifying.remove(entry.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: const Color(0xFF262626), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF2E5A59),
            blurRadius: 64,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: StreamBuilder<List<WaitlistEntry>>(
        stream: WaitlistService.watchStakesWaitlist(
          clubId: widget.clubId,
          stakesKey: widget.stakesKey,
        ),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <WaitlistEntry>[];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;
          final hasError = snapshot.hasError;

          return Column(
            children: [
              // Standard drawer header — close (left), title (center), spacer (right)
              _buildHeader(),
              const SizedBox(height: 24),
              // Stakes + count subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Cash Game ${widget.stakesDisplay}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mint900,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entries.length}',
                        style: GoogleFonts.ibmPlexSans(
                          color: AppColors.buttonPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Body — list / loading / empty / error
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildBody(
                    entries: entries,
                    isLoading: isLoading,
                    hasError: hasError,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button — left
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF35373C),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Title — center
          Text(
            'Waitlist',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.43,
            ),
          ),
          // Right-side spacer to keep title centered
          const SizedBox(width: 38, height: 38),
        ],
      ),
    );
  }

  Widget _buildBody({
    required List<WaitlistEntry> entries,
    required bool isLoading,
    required bool hasError,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.buttonPrimary,
          ),
        ),
      );
    }
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Could not load waitlist',
          style: GoogleFonts.ibmPlexSans(color: AppColors.errorRed),
        ),
      );
    }
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 40,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              'No one on the waitlist',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildEntryRow(entries[index], index + 1);
      },
    );
  }

  Widget _buildEntryRow(WaitlistEntry entry, int position) {
    final isNotified = entry.status == WaitlistStatus.notified;
    final isBusy = _notifying.contains(entry.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: isNotified
            ? Border.all(color: AppColors.buttonPrimary, width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Position chip — mint circle when first waiting, neutral otherwise
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isNotified
                  ? AppColors.mint900
                  : (position == 1
                      ? AppColors.mint900
                      : const Color(0xFF2A2A2E)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isNotified
                  ? const Icon(
                      Icons.notifications_active,
                      color: AppColors.buttonPrimary,
                      size: 16,
                    )
                  : Text(
                      '$position',
                      style: GoogleFonts.ibmPlexSans(
                        color: position == 1
                            ? AppColors.buttonPrimary
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.userDisplayName.isEmpty
                      ? 'Player'
                      : entry.userDisplayName,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isNotified
                      ? 'Notified • ${_formatJoinedAt(entry.joinedAt)}'
                      : 'Joined ${_formatJoinedAt(entry.joinedAt)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: isNotified
                        ? AppColors.buttonPrimary
                        : AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Notify bell button
          GestureDetector(
            onTap: isBusy ? null : () => _notify(entry),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isNotified
                    ? AppColors.mint900
                    : AppColors.mint900.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.buttonPrimary,
                      ),
                    )
                  : Icon(
                      isNotified
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: 18,
                      color: AppColors.buttonPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinedAt(DateTime joinedAt) {
    final now = DateTime.now();
    final diff = now.difference(joinedAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Admin-only drawer for adding a table to the current stakes group.
///
/// Offers two paths:
///   1. Create a brand-new table (inline form at the top) — the new table is
///      attached to the first event in the group.
///   2. Attach an existing club table from the list below. Tables that are
///      currently tied to a live (active) event are shown greyed-out with
///      the owning event name as a subtitle and cannot be tapped.
///
/// Uses the standard app drawer chrome (black bg, 32px top radius,
/// `#262626` border, teal glow shadow, 38×38 close button header).
class _AddTableSheet extends StatefulWidget {
  final Club club;
  final String stakes;
  final List<ClubEvent> groupEvents;
  final Future<void> Function() onTableAdded;

  const _AddTableSheet({
    required this.club,
    required this.stakes,
    required this.groupEvents,
    required this.onTableAdded,
  });

  @override
  State<_AddTableSheet> createState() => _AddTableSheetState();
}

class _AddTableSheetState extends State<_AddTableSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;
  bool _isCreating = false;
  String? _attachingTableId;
  String? _error;

  /// All tables in the club.
  List<PokerTable> _allTables = [];

  /// Table IDs currently attached to a LIVE (active) event — keyed by
  /// tableId, valued by the owning event's display name.
  final Map<String, String> _liveBusyTableIds = {};

  /// Table IDs attached to events in the CURRENT group (also live, but
  /// we treat these as already-here so they are hidden from the list).
  final Set<String> _groupTableIds = {};

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    try {
      final allTables = await TableService.getTables(widget.club.id);
      final activeEvents = await EventService.getActiveEvents(widget.club.id);

      final groupEventIds = widget.groupEvents.map((e) => e.id).toSet();
      final liveBusy = <String, String>{};
      final groupTables = <String>{};
      for (final event in activeEvents) {
        for (final tableId in event.tableIds) {
          if (groupEventIds.contains(event.id)) {
            groupTables.add(tableId);
          } else {
            liveBusy[tableId] = event.name;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _allTables = allTables;
        _liveBusyTableIds
          ..clear()
          ..addAll(liveBusy);
        _groupTableIds
          ..clear()
          ..addAll(groupTables);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load tables: $e';
        _isLoading = false;
      });
    }
  }

  /// The first event in the group — new tables get attached here. Since all
  /// events in a group share the same stakes, the choice is cosmetic.
  ClubEvent get _targetEvent => widget.groupEvents.first;

  Future<void> _createAndAttachNewTable() async {
    if (_isCreating) return;
    final name = _nameController.text.trim();

    // Next table number = max existing + 1.
    final maxNumber = _allTables.isEmpty
        ? 0
        : _allTables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b);
    final nextNumber = maxNumber + 1;

    setState(() => _isCreating = true);
    try {
      final newTable = await TableService.createTable(
        clubId: widget.club.id,
        tableNumber: nextNumber,
        name: name.isEmpty ? null : name,
      );
      await EventService.addTableToEvent(
        clubId: widget.club.id,
        eventId: _targetEvent.id,
        tableId: newTable.id,
      );
      await widget.onTableAdded();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${newTable.name} to the group'),
          backgroundColor: AppColors.mint700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add table: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _attachExistingTable(PokerTable table) async {
    if (_attachingTableId != null) return;
    setState(() => _attachingTableId = table.id);
    try {
      await EventService.addTableToEvent(
        clubId: widget.club.id,
        eventId: _targetEvent.id,
        tableId: table.id,
      );
      await widget.onTableAdded();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${table.name} to the group'),
          backgroundColor: AppColors.mint700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _attachingTableId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to attach table: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: const Color(0xFF262626), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF2E5A59),
            blurRadius: 64,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          // Subtitle — which group we're adding to.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Cash Game ${widget.stakes}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF35373C),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          Text(
            'Add Table',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.43,
            ),
          ),
          const SizedBox(width: 38, height: 38),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.ibmPlexSans(color: AppColors.errorRed),
        ),
      );
    }

    // Partition tables into available (free OR tied only to non-live events
    // like scheduled/completed) and live-busy (tied to another live event).
    // Tables already in this group are excluded — they're already visible
    // on the grid behind the drawer.
    final available = <PokerTable>[];
    final liveBusy = <PokerTable>[];
    for (final table in _allTables) {
      if (_groupTableIds.contains(table.id)) continue;
      if (_liveBusyTableIds.containsKey(table.id)) {
        liveBusy.add(table);
      } else {
        available.add(table);
      }
    }
    available.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
    liveBusy.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildNewTableForm(),
        const SizedBox(height: 24),
        _buildSectionLabel('Available tables'),
        const SizedBox(height: 12),
        if (available.isEmpty && liveBusy.isEmpty)
          _buildEmptyRow('No other tables in this club yet'),
        ...available.map((t) => _buildTableRow(t, isBusy: false)),
        if (liveBusy.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('In use by other events'),
          const SizedBox(height: 12),
          ...liveBusy.map((t) => _buildTableRow(t, isBusy: true)),
        ],
      ],
    );
  }

  Widget _buildNewTableForm() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F23),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _nameController,
              enabled: !_isCreating,
              cursorColor: AppColors.buttonPrimary,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'New table name (optional)',
                hintStyle: GoogleFonts.ibmPlexSans(
                  color: AppColors.textDisabled,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isCreating ? null : _createAndAttachNewTable,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _isCreating
                  ? AppColors.mint900
                  : AppColors.buttonPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.buttonPrimary,
                    ),
                  )
                : Text(
                    'Add',
                    style: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFF02050B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.ibmPlexSans(
        color: AppColors.textDisabled,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyRow(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSans(
          color: AppColors.textDisabled,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTableRow(PokerTable table, {required bool isBusy}) {
    final isAttaching = _attachingTableId == table.id;
    final subtitle = isBusy
        ? 'In use by ${_liveBusyTableIds[table.id] ?? 'another event'}'
        : 'Seats ${table.qrCodes.length > 0 ? table.qrCodes.length : 9}';

    return Opacity(
      opacity: isBusy ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: isBusy || isAttaching ? null : () => _attachExistingTable(table),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F23),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2E),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${table.tableNumber}',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      table.name,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.ibmPlexSans(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isAttaching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.buttonPrimary,
                  ),
                )
              else if (!isBusy)
                const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.buttonPrimary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
