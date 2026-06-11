import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/stack_bucket.dart';
import '../../screens/hand_actions_screen.dart';
import '../../services/range_grid_cloud_backfill.dart';
import '../../services/range_grid_service.dart';
import 'range_frequency_bar.dart';
import 'range_hand_row.dart';

/// The hero's PREFLOP range chart, built purely from logged hands.
///
/// Renders the full 13×13 starting-hand grid: cells start empty and fill
/// with the hero's actual preflop action frequencies as hands with hole
/// cards are logged, sliced by game type, position and stack range. Only
/// preflop decisions are considered — postflop play never affects a cell.
class RangeGridView extends StatefulWidget {
  const RangeGridView({super.key});

  @override
  State<RangeGridView> createState() => _RangeGridViewState();
}

class _RangeGridViewState extends State<RangeGridView>
    with AutomaticKeepAliveClientMixin {
  static const _ranks = 'AKQJT98765432';
  static const _posGroups = ['EP', 'MP', 'CO', 'BTN', 'SB', 'BB'];

  String _gameType = 'cash';
  String? _posGroup; // null = all positions
  String? _stackBucket; // null = all stacks

  Map<String, RangeCellAggregate> _aggregates = {};
  bool _loading = true;
  bool _syncingCloud = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _syncCloudHistory();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final aggregates = await RangeGridService.aggregateByHandClass(
      gameType: _gameType,
      posGroup: _posGroup,
      stackBucket: _stackBucket,
    );
    if (!mounted) return;
    setState(() {
      _aggregates = aggregates;
      _loading = false;
    });
  }

  /// Pull the full hand history from Firestore once and refresh the grid
  /// when it lands, so prior hands show up without any new logging.
  Future<void> _syncCloudHistory({bool force = false}) async {
    setState(() => _syncingCloud = true);
    final indexedNew =
        await RangeGridCloudBackfill.ensureCloudBackfilled(force: force);
    if (!mounted) return;
    setState(() => _syncingCloud = false);
    if (indexedNew) _load();
  }

  void _setFilter(VoidCallback apply) {
    HapticFeedback.selectionClick();
    setState(apply);
    _load();
  }

  /// Hand class for grid cell (row, col): pairs on the diagonal, suited
  /// above (row < col), offsuit below.
  String _classFor(int row, int col) {
    if (row == col) return '${_ranks[row]}${_ranks[row]}';
    if (row < col) return '${_ranks[row]}${_ranks[col]}s';
    return '${_ranks[col]}${_ranks[row]}o';
  }

  Color? _dominantColor(RangeCellAggregate agg) {
    if (agg.total == 0) return null;
    final entries = <(int, Color)>[
      (agg.raiseCount, RangeFrequencyBar.raiseColor),
      (agg.callCount, RangeFrequencyBar.callColor),
      (agg.checkCount, RangeFrequencyBar.checkColor),
      (agg.foldCount, RangeFrequencyBar.foldColor),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return entries.first.$2;
  }

  int get _loggedClassCount =>
      _aggregates.values.where((a) => a.total > 0).length;

  // ── Filters ─────────────────────────────────────────────────────────
  //
  // Compact, no horizontal scrolling:
  //  Row 1: Cash|Tournament mini segmented toggle + stack depth selector
  //  Row 2: full-width position segmented bar (All/EP/MP/CO/BTN/SB/BB)

  Widget _buildGameTypeToggle() {
    Widget segment(String label, String value) {
      final selected = _gameType == value;
      return GestureDetector(
        onTap: selected ? null : () => _setFilter(() => _gameType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF62E3BC) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.black
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('Cash', 'cash'),
          segment('Tourney', 'tournament'),
        ],
      ),
    );
  }

  String get _stackLabel => _stackBucket == null
      ? 'All stacks'
      : StackBucketHelper.rangeLabel(
          StackRange.values.firstWhere(
            (r) => r.name == _stackBucket,
            orElse: () => StackRange.average,
          ),
        );

  Widget _buildStackSelector() {
    final active = _stackBucket != null;
    return GestureDetector(
      onTap: _showStackPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF62E3BC) : const Color(0xFF161719),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? const Color(0xFF62E3BC)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 14,
              color: active ? Colors.black : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              _stackLabel,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? Colors.black : Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showStackPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget option(String label, String? value) {
          final selected = _stackBucket == value;
          return GestureDetector(
            onTap: () {
              Navigator.pop(sheetContext);
              if (_stackBucket != value) {
                _setFilter(() => _stackBucket = value);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: selected
                        ? const Color(0xFF62E3BC)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161719),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 14, 24, 16 + MediaQuery.of(sheetContext).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Stack depth',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              option('All stacks', null),
              for (final range in StackRange.values)
                option(StackBucketHelper.rangeLabel(range), range.name),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionBar() {
    Widget segment(String label, String? value) {
      final selected = _posGroup == value;
      return Expanded(
        child: GestureDetector(
          onTap: selected ? null : () => _setFilter(() => _posGroup = value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF62E3BC) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.black
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          segment('All', null),
          for (final group in _posGroups) segment(group, group),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildGameTypeToggle(),
              const Spacer(),
              _buildStackSelector(),
            ],
          ),
          const SizedBox(height: 8),
          _buildPositionBar(),
        ],
      ),
    );
  }

  // ── Grid ────────────────────────────────────────────────────────────

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: GridView.count(
            crossAxisCount: 13,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (int row = 0; row < 13; row++)
                for (int col = 0; col < 13; col++) _buildCell(row, col),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final handClass = _classFor(row, col);
    final agg = _aggregates[handClass];
    final color = agg != null ? _dominantColor(agg) : null;
    final hasData = color != null;

    // More samples → stronger tint (caps at 6 samples)
    final intensity =
        hasData ? (0.25 + 0.6 * (agg!.total / 6).clamp(0.0, 1.0)) : 0.0;

    return GestureDetector(
      onTap: hasData ? () => _showCellDetail(handClass) : null,
      child: Container(
        decoration: BoxDecoration(
          color: hasData
              ? color.withValues(alpha: intensity)
              : const Color(0xFF161719),
          borderRadius: BorderRadius.circular(3),
          border: row == col
              ? Border.all(color: Colors.white.withValues(alpha: 0.07))
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: Text(
                handClass,
                style: GoogleFonts.robotoMono(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: hasData
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverage() {
    final logged = _loggedClassCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.06)),
                    FractionallySizedBox(
                      widthFactor: (logged / 169).clamp(0.0, 1.0),
                      child: Container(color: const Color(0xFF62E3BC)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$logged / 169 hands logged',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    Widget item(String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        children: [
          item('Raise', RangeFrequencyBar.raiseColor),
          item('Call', RangeFrequencyBar.callColor),
          item('Check', RangeFrequencyBar.checkColor),
          item('Fold', RangeFrequencyBar.foldColor),
        ],
      ),
    );
  }

  Widget _buildSyncRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Color(0xFF62E3BC)),
          ),
          const SizedBox(width: 8),
          Text(
            'Syncing your hand history…',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cell detail sheet ───────────────────────────────────────────────

  void _showCellDetail(String handClass) {
    final agg = _aggregates[handClass];
    if (agg == null || agg.total == 0) return;

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CellDetailSheet(
        handClass: handClass,
        gameType: _gameType,
        posGroup: _posGroup,
        stackBucket: _stackBucket,
        aggregate: agg,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin

    return RefreshIndicator(
      onRefresh: () async {
        await _syncCloudHistory(force: true);
        await _load();
      },
      color: const Color(0xFF62E3BC),
      backgroundColor: const Color(0xFF161719),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 120),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          if (_syncingCloud) _buildSyncRow(),
          const SizedBox(height: 14),
          // Preflop-only scope, stated explicitly
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'PREFLOP RANGE — BUILT FROM YOUR LOGGED HANDS',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: const Color(0xFF87ED81),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 120),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF62E3BC)),
                ),
              ),
            )
          else ...[
            _buildGrid(),
            const SizedBox(height: 12),
            _buildCoverage(),
            const SizedBox(height: 12),
            _buildLegend(),
            if (_loggedClassCount == 0 && !_syncingCloud) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your preflop chart builds itself: log hands and enter your '
                  'hole cards, and each starting hand fills in with how you '
                  'actually played it before the flop.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the preflop frequency split and recent hands for one cell.
class _CellDetailSheet extends StatefulWidget {
  final String handClass;
  final String gameType;
  final String? posGroup;
  final String? stackBucket;
  final RangeCellAggregate aggregate;

  const _CellDetailSheet({
    required this.handClass,
    required this.gameType,
    required this.posGroup,
    required this.stackBucket,
    required this.aggregate,
  });

  @override
  State<_CellDetailSheet> createState() => _CellDetailSheetState();
}

class _CellDetailSheetState extends State<_CellDetailSheet> {
  late final Future<List<RangeGridEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = RangeGridService.queryHandClass(
      gameType: widget.gameType,
      handClass: widget.handClass,
      posGroup: widget.posGroup,
      stackBucket: widget.stackBucket,
    );
  }

  Future<void> _openHand(RangeGridEntry entry) async {
    final hand = await RangeGridService.loadHand(entry);
    if (hand == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HandActionsScreen(hand: hand)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agg = widget.aggregate;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161719),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                widget.handClass,
                style: GoogleFonts.robotoMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF62E3BC),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${agg.total} preflop ${agg.total == 1 ? 'spot' : 'spots'}'
                '${widget.posGroup != null ? ' · ${widget.posGroup}' : ''}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RangeFrequencyBar(
            raiseCount: agg.raiseCount,
            callCount: agg.callCount,
            foldCount: agg.foldCount,
            checkCount: agg.checkCount,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          Flexible(
            child: FutureBuilder<List<RangeGridEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF62E3BC)),
                      ),
                    ),
                  );
                }
                final entries = snapshot.data!;
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in entries)
                      RangeHandRow(entry: entry, onTap: () => _openHand(entry)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
