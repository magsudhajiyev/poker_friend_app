import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/drill_models.dart';
import '../../services/drill_engine.dart';
import '../../widgets/hand_micro_animations.dart';
import '../../widgets/poker_table_widget.dart';

/// The drill loop: one preflop hand at a time against bots that play like
/// the user's real opponents, with instant exploit-based grading.
/// Rendered on the app's shared oval table (PokerTableWidget) so drills
/// look and feel like a real logged hand. Nothing here persists — training
/// is fully isolated from real data.
class DrillTableScreen extends StatefulWidget {
  final List<DrillSeat> seats;
  final double stackBB;

  const DrillTableScreen({
    super.key,
    required this.seats,
    required this.stackBB,
  });

  @override
  State<DrillTableScreen> createState() => _DrillTableScreenState();
}

enum _Phase { acting, feedback, handOver }

/// Direction to offset the action pill from the seat toward the table center.
enum _ChipDir { up, down, left, right }

class _DrillTableScreenState extends State<DrillTableScreen>
    with TickerProviderStateMixin {
  static const _accent = Color(0xFF89F1EC);
  static const _gold = Color(0xFFFFC857);
  static const _red = Color(0xFFE85D5D);
  static const _green = Color(0xFF54E98A);
  static const _chipWhite = Color(0xFFCCCCCC);

  late final DrillEngine _engine;
  final Set<int> _foldedSeats = {};
  final Map<int, String> _lastAction = {}; // seat -> compact action label
  final List<String> _recentLines = []; // newest last, capped
  final List<DrillDecisionRecord> _records = [];

  // Chip flight animation state
  final List<_DrillChipFlight> _chipFlights = [];
  final GlobalKey _tableAreaKey = GlobalKey();
  int _chipSeed = 0;

  // Maps actual seat number → visual position on the 9-seat oval.
  // Hero is always placed at visual position 5 (bottom center).
  late final Map<int, int> _visualSeatMap;

  _Phase _phase = _Phase.handOver;
  DrillHeroTurn? _heroTurn;
  DrillGradeResult? _lastGrade;
  DrillHandUpdate? _lastUpdate;
  bool _showRaiseSizes = false;
  String _handOverNote = '';

  int get _correct =>
      _records.where((r) => r.result.grade == DrillGrade.correct).length;

  @override
  void initState() {
    super.initState();
    _engine = DrillEngine(seats: widget.seats, stackBB: widget.stackBB);
    _visualSeatMap = _buildVisualSeatMap();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nextHand());
  }

  /// Reverse lookup: visual position → actual seat number.
  int _actualSeat(int visualSeat) {
    return _visualSeatMap.entries
        .firstWhere((e) => e.value == visualSeat)
        .key;
  }

  /// Builds a mapping from actual seat numbers to visual positions (1-9)
  /// so that the hero always sits at position 5 (bottom center of the oval).
  /// Other seats are evenly distributed around the remaining positions.
  Map<int, int> _buildVisualSeatMap() {
    final sorted = widget.seats.map((s) => s.seatNumber).toList()..sort();
    final heroActual =
        widget.seats.firstWhere((s) => s.isHero).seatNumber;
    final n = sorted.length;
    final heroIdx = sorted.indexOf(heroActual);

    // Visual positions to use: evenly spaced around 9 slots.
    // For n players we pick n positions centered on slot 5.
    // E.g. 6 players → [1, 2, 3, 5, 7, 8] (skip 4, 6, 9)
    // Simpler: just space them evenly across 1..9.
    final visualSlots = <int>[];
    if (n >= 9) {
      visualSlots.addAll([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    } else {
      // Place hero at 5, distribute others evenly
      for (int i = 0; i < n; i++) {
        // Offset from hero in the seat order
        final offset = (i - heroIdx + n) % n;
        // Map to visual position: hero=5, each step = 9/n slots clockwise
        final visual = ((5 - 1 + (offset * 9 / n).round()) % 9) + 1;
        visualSlots.add(visual);
      }
    }

    final map = <int, int>{};
    for (int i = 0; i < n; i++) {
      map[sorted[i]] = visualSlots[i];
    }
    return map;
  }

  @override
  void dispose() {
    for (final f in _chipFlights) {
      f.controller.dispose();
    }
    super.dispose();
  }

  // ── Drill flow ──────────────────────────────────────────────────────

  void _nextHand() {
    // Dispose and clear lingering chip flights from previous hand
    for (final f in _chipFlights) {
      f.controller.dispose();
    }
    _chipFlights.clear();

    setState(() {
      _foldedSeats.clear();
      _lastAction.clear();
      _recentLines.clear();
      _lastGrade = null;
      _showRaiseSizes = false;
      _handOverNote = '';
      _consume(_engine.startHand());
    });
  }

  void _act(String action, {double? raiseToBB}) {
    if (_phase != _Phase.acting) return;
    setState(() {
      _showRaiseSizes = false;
      _consume(_engine.applyHeroAction(action, raiseToBB: raiseToBB));
    });
  }

  void _consume(DrillHandUpdate update) {
    _lastUpdate = update;
    // Collect seats that need chip flights this batch
    final flightQueue = <(int seat, String action)>[];

    for (final e in update.newEvents) {
      if (e.action == 'folds') _foldedSeats.add(e.seat);
      _lastAction[e.seat] = _actionLabel(e);
      if (!e.action.startsWith('posts')) {
        final amount = e.toAmountBB != null
            ? ' to ${e.toAmountBB!.toStringAsFixed(1)}BB'
            : '';
        _recentLines.add('${e.name} (${e.position}) ${e.action}$amount');
        if (_recentLines.length > 3) _recentLines.removeAt(0);
      }

      // Queue chip flight for money actions (not folds/checks)
      if (e.action != 'folds' && e.action != 'checks') {
        flightQueue.add((e.seat, e.action));
      }
    }

    // Fire chip flights after the frame so layout positions are valid
    if (flightQueue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final (seat, action) in flightQueue) {
          _fireChipFlight(seat, action);
        }
      });
    }

    if (update.grade != null) {
      _lastGrade = update.grade;
      _records.add(DrillDecisionRecord(
        handNumber: _engine.handNumber,
        handClass: _engine.heroHandClass,
        position: _engine.heroPosition,
        scenario: _heroTurn?.scenario ?? DrillScenario.unopened,
        result: update.grade!,
      ));
    }

    if (update.awaitingHero) {
      _heroTurn = update.heroTurn;
      // Pause on feedback before the next decision in the same hand
      _phase = update.grade != null ? _Phase.feedback : _Phase.acting;
    } else if (update.handComplete) {
      _heroTurn = null;
      _phase = update.grade != null ? _Phase.feedback : _Phase.handOver;
      _handOverNote = _completionNote(update);
      if (update.heroWalked) {
        // No decision was possible — flow straight into the next hand
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted && _phase == _Phase.handOver) _nextHand();
          });
        });
      }
    }
  }

  String _actionLabel(DrillEvent e) {
    final amount = e.toAmountBB?.toStringAsFixed(1) ?? '';
    switch (e.action) {
      case 'posts SB':
        return 'SB 0.5';
      case 'posts BB':
        return 'BB 1';
      case 'folds':
        return 'FOLD';
      case 'checks':
        return 'CHECK';
      case 'limps':
        return 'LIMP';
      case 'calls':
        return 'CALL $amount';
      case 'raises':
        return 'RAISE $amount';
      case '3-bets':
        return '3-BET $amount';
      case '4-bets':
        return '4-BET $amount';
      case 'jams':
        return 'JAM $amount';
      default:
        return e.action.toUpperCase();
    }
  }

  void _dismissFeedback() {
    setState(() {
      _phase = (_lastUpdate?.awaitingHero ?? false)
          ? _Phase.acting
          : _Phase.handOver;
    });
  }

  String _completionNote(DrillHandUpdate update) {
    if (update.heroWalked) return 'Everyone folded — you win the blinds.';
    if (update.heroWonUncontested) {
      return 'Everyone folded — you take it down '
          '(${update.potBB.toStringAsFixed(1)}BB).';
    }
    if (update.reachedFlop) {
      return 'Hand goes to the flop — preflop drill complete.';
    }
    return 'Hand over.';
  }

  Future<void> _confirmExit() async {
    if (_records.isEmpty) {
      Navigator.pop(context);
      return;
    }
    await _showSummary();
  }

  Future<void> _showSummary() async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF131616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DrillSummarySheet(records: _records),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  /// Scale factor relative to iPhone 13 (812 logical height).
  /// Keeps the UI proportional on iPhone 11, 16 Pro, SE, etc.
  double _s(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return (h / 812).clamp(0.8, 1.25);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(s),
              Expanded(child: _buildTable(s)),
              _buildHeroRow(s),
              _buildRecentLines(s),
              _buildBottomPanel(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double s) {
    final total = _records.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 4 * s),
      child: Row(
        children: [
          GestureDetector(
            onTap: _confirmExit,
            child: Container(
              width: 36 * s,
              height: 36 * s,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.white, size: 20 * s),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hand #${_engine.handNumber}',
                    style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${widget.stackBB.toInt()}BB · ${widget.seats.length}-handed',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12 * s),
                ),
              ],
            ),
          ),
          if (total > 0)
            GestureDetector(
              onTap: _showSummary,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 12 * s, vertical: 6 * s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  '$_correct/$total',
                  style: GoogleFonts.robotoMono(
                      color: _green,
                      fontSize: 14 * s,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Table ───────────────────────────────────────────────────────────

  // Seat fractions matching the table surface so seats land on the rim.
  static const _seatW = 0.92;
  static const _seatH = 0.82;

  Widget _buildTable(double s) {
    // Build active seat map using visual positions
    final activeSeatMap = {
      for (final seat in widget.seats) _visualSeatMap[seat.seatNumber]!: true,
    };
    // Map dealer button to its visual position
    final visualButton = _engine.handNumber > 0
        ? _visualSeatMap[_engine.buttonSeat]
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
      child: Stack(
        key: _tableAreaKey,
        clipBehavior: Clip.none,
        children: [
          PokerTableWidget(
            activeSeatMap: activeSeatMap,
            buttonPosition: visualButton,
            showDealerButton: _engine.handNumber > 0,
            showLogo: false,
            seatWidthFraction: _seatW,
            seatHeightFraction: _seatH,
            seatBuilder: (visualSeat, isActive) =>
                isActive ? _buildSeat(_actualSeat(visualSeat), s) : const SizedBox.shrink(),
            centerContent: _buildPot(s),
          ),
          // Chip flight overlay — painted above the table
          if (_chipFlights.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ChipFlightPainter(
                    flights: _chipFlights
                        .map((f) => ChipFlightFrame(
                              start: f.start,
                              end: f.end,
                              color: f.color,
                              progress: f.controller.value,
                              seed: f.seed,
                              chipCount: f.chipCount,
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPot(double s) {
    if (_engine.handNumber == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('POT',
            style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11 * s,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        Text(
          '${(_lastUpdate?.potBB ?? _engine.potBB).toStringAsFixed(1)}BB',
          style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 20 * s,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSeat(int actualSeatNumber, double s) {
    final seatNumber = actualSeatNumber;
    final visualSeat = _visualSeatMap[seatNumber]!;
    final seat =
        widget.seats.firstWhere((s) => s.seatNumber == seatNumber);
    final folded = _foldedSeats.contains(seatNumber);
    final action = _lastAction[seatNumber];
    final position = _engine.positionOf(seatNumber);
    final heroActing = seat.isHero && _phase == _Phase.acting;

    final name = seat.displayName.length > 8
        ? '${seat.displayName.substring(0, 7)}…'
        : seat.displayName;

    // Player info pill
    final playerInfo = Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: heroActing
              ? _accent
              : seat.isHero
                  ? _accent.withOpacity(0.55)
                  : const Color(0xFF2C2C2E),
          width: heroActing ? 2 : 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            style: GoogleFonts.ibmPlexSans(
              color: seat.isHero ? _accent : Colors.white,
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (position.isNotEmpty)
            Text(
              position,
              style: GoogleFonts.robotoMono(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10 * s,
                height: 1.2,
              ),
            ),
        ],
      ),
    );

    // Action/bet pill — placed toward the table center
    Widget? statusPill;
    if (action != null) {
      final pillColor = _actionColor(action);
      final pillTrigger = action;
      statusPill = PopIn(
        triggerKey: pillTrigger,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 5 * s, vertical: 1 * s),
          decoration: BoxDecoration(
            color: pillColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            action,
            style: GoogleFonts.robotoMono(
              color: pillColor,
              fontSize: 9 * s,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    Widget content;
    if (statusPill == null) {
      content = playerInfo;
    } else {
      final gap = 3 * s;
      final dir = _chipDirection(visualSeat);
      switch (dir) {
        case _ChipDir.up:
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [statusPill, SizedBox(height: gap), playerInfo],
          );
        case _ChipDir.down:
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [playerInfo, SizedBox(height: gap), statusPill],
          );
        case _ChipDir.left:
          content = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [statusPill, SizedBox(width: gap), playerInfo],
          );
        case _ChipDir.right:
          content = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [playerInfo, SizedBox(width: gap), statusPill],
          );
      }
    }

    return Opacity(
      opacity: folded ? 0.35 : 1.0,
      child: content,
    );
  }

  /// Returns the direction the action pill should be placed relative to
  /// the seat so it appears "in front of" the player on the table felt.
  /// Vertical table layout — seats around an oval.
  _ChipDir _chipDirection(int seatNumber) {
    switch (seatNumber) {
      case 1:
        return _ChipDir.down; // top of table → pill down toward center
      case 9:
        return _ChipDir.down; // top of table → pill down toward center
      case 2:
        return _ChipDir.left; // right side → pill left toward center
      case 3:
        return _ChipDir.left; // right side → pill left toward center
      case 4:
        return _ChipDir.up; // bottom-right → pill up toward center
      case 5:
        return _ChipDir.up; // bottom → pill up toward center
      case 6:
        return _ChipDir.up; // bottom-left → pill up toward center
      case 7:
        return _ChipDir.right; // left side → pill right toward center
      case 8:
        return _ChipDir.right; // left side → pill right toward center
      default:
        return _ChipDir.down;
    }
  }

  // ── Chip flight animations ─────────────────────────────────────────

  void _fireChipFlight(int fromActualSeat, String action) {
    final renderBox =
        _tableAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final visualSeat = _visualSeatMap[fromActualSeat] ?? fromActualSeat;
    final areaSize = renderBox.size;
    final seatPos = PokerTableWidget.getSeatPosition(
      visualSeat,
      areaSize,
      widthFraction: _seatW,
      heightFraction: _seatH,
    );
    final potPos = Offset(areaSize.width / 2, areaSize.height / 2);

    final color = _chipFlightColor(action);
    final chipCount = _chipFlightCount(action);
    final seed = _chipSeed++;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final flight = _DrillChipFlight(
      controller: controller,
      start: seatPos,
      end: potPos,
      color: color,
      seed: seed,
      chipCount: chipCount,
    );

    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _chipFlights.remove(flight);
        controller.dispose();
        if (mounted) setState(() {});
      }
    });

    _chipFlights.add(flight);
    controller.forward();
  }

  Color _chipFlightColor(String action) {
    switch (action) {
      case 'posts SB':
      case 'posts BB':
        return _chipWhite;
      case 'raises':
      case '3-bets':
      case '4-bets':
        return _gold;
      case 'jams':
        return _red;
      default: // calls, limps
        return _accent;
    }
  }

  int _chipFlightCount(String action) {
    switch (action) {
      case 'posts SB':
        return 1;
      case 'posts BB':
        return 2;
      case 'limps':
      case 'calls':
        return 3;
      case 'raises':
      case '3-bets':
      case '4-bets':
        return 4;
      case 'jams':
        return 5;
      default:
        return 2;
    }
  }

  Color _actionColor(String label) {
    if (label.startsWith('FOLD')) return Colors.white60;
    if (label.startsWith('RAISE') ||
        label.startsWith('3-BET') ||
        label.startsWith('4-BET') ||
        label.startsWith('JAM')) {
      return _gold;
    }
    if (label.startsWith('SB') || label.startsWith('BB')) {
      return Colors.white70;
    }
    return _accent; // call / limp / check
  }

  // ── Hero strip / recent lines ───────────────────────────────────────

  Widget _buildHeroRow(double s) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 4 * s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final card in _engine.heroCards) ...[
            _buildCard(card, s),
            SizedBox(width: 6 * s),
          ],
          SizedBox(width: 8 * s),
          Text(_engine.heroHandClass,
              style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 17 * s,
                  fontWeight: FontWeight.w600)),
          SizedBox(width: 8 * s),
          Text(_engine.heroPosition,
              style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.4), fontSize: 13 * s)),
        ],
      ),
    );
  }

  Widget _buildCard(String card, double s) {
    final suit = card.substring(card.length - 1);
    final rank = card.substring(0, card.length - 1);
    final isRed = suit == '♥' || suit == '♦';
    final color = isRed ? const Color(0xFFD32F2F) : Colors.black;
    return Container(
      width: 34 * s,
      height: 46 * s,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6 * s),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank,
              style: GoogleFonts.robotoMono(
                  color: color,
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w700)),
          Text(suit, style: TextStyle(color: color, fontSize: 12 * s)),
        ],
      ),
    );
  }

  Widget _buildRecentLines(double s) {
    final text = _handOverNote.isNotEmpty
        ? _handOverNote
        : _recentLines.isNotEmpty
            ? _recentLines.last
            : '';
    return SizedBox(
      height: 22 * s,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.ibmPlexSans(
            color: _handOverNote.isNotEmpty
                ? _accent.withOpacity(0.85)
                : Colors.white.withOpacity(0.55),
            fontSize: 13 * s,
            fontStyle:
                _handOverNote.isNotEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  // ── Bottom panel ────────────────────────────────────────────────────

  Widget _buildBottomPanel(double s) {
    return Container(
      padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 16 * s),
      child: switch (_phase) {
        _Phase.feedback => _buildFeedback(s),
        _Phase.acting => _buildActions(s),
        _Phase.handOver => _buildHandOver(s),
      },
    );
  }

  Widget _buildFeedback(double s) {
    final grade = _lastGrade!;
    final (color, label) = switch (grade.grade) {
      DrillGrade.correct => (_green, 'CORRECT'),
      DrillGrade.ok => (_gold, 'CLOSE'),
      DrillGrade.mistake => (_red, 'MISTAKE'),
    };
    final diverge = !grade.linesAgree;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(label,
                  style: GoogleFonts.ibmPlexSans(
                      color: color,
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              SizedBox(width: 8 * s),
              Text('· you chose ${grade.heroAction}',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12 * s)),
              const Spacer(),
              Text(
                '${_engine.heroHandClass} = top ${grade.handTopPercent.round()}%',
                style: GoogleFonts.robotoMono(
                    color: Colors.white.withOpacity(0.5), fontSize: 11 * s),
              ),
            ],
          ),
          if (diverge) ...[
            SizedBox(height: 8 * s),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 8 * s, vertical: 4 * s),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8 * s),
              ),
              child: Text(
                'This lineup changes the play: GTO ${grade.gtoAction}s, exploit ${grade.exploitAction}s',
                style: GoogleFonts.ibmPlexSans(
                    color: _accent,
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          SizedBox(height: 10 * s),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.26),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _evalRow(
                    'GTO',
                    Colors.white.withOpacity(0.5),
                    grade.gtoAction,
                    grade.gtoRangePercent,
                    grade.gtoReason,
                    highlight: false,
                    s: s,
                  ),
                  SizedBox(height: 8 * s),
                  _evalRow(
                    'EXPLOIT',
                    _accent,
                    grade.exploitAction,
                    grade.exploitRangePercent,
                    grade.exploitReason,
                    highlight: diverge,
                    s: s,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          GestureDetector(
            onTap: _dismissFeedback,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12 * s),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Center(
                child: Text(
                  (_lastUpdate?.awaitingHero ?? false)
                      ? 'Continue'
                      : 'Got it',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.black,
                      fontSize: 15 * s,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One line of the dual evaluation: a tag (GTO/EXPLOIT), the recommended
  /// action coloured by type, the range cutoff, and the reasoning.
  Widget _evalRow(String tag, Color tagColor, String action,
      double rangePercent, String reason,
      {required bool highlight, required double s}) {
    final actionColor = switch (action) {
      'raise' => _gold,
      'call' || 'check' => _accent,
      _ => _red,
    };
    return Container(
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: highlight ? _accent.withOpacity(0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(10 * s),
        border: highlight
            ? Border.all(color: _accent.withOpacity(0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64 * s,
                child: Text(tag,
                    style: GoogleFonts.ibmPlexSans(
                        color: tagColor,
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
              Text(action.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(
                      color: actionColor,
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (rangePercent > 0 && rangePercent < 100)
                Text('top ${rangePercent.round()}%',
                    style: GoogleFonts.robotoMono(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10 * s)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            SizedBox(height: 3 * s),
            Text(reason,
                style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12 * s,
                    height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(double s) {
    final turn = _heroTurn;
    if (turn == null) return const SizedBox.shrink();

    if (_showRaiseSizes) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Raise to:',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13 * s)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showRaiseSizes = false),
                child: Icon(Icons.close,
                    size: 18 * s, color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Row(
            children: [
              for (final size in turn.suggestedRaiseToBB) ...[
                Expanded(
                  child: _actionButton(
                    size >= turn.maxRaiseToBB
                        ? 'JAM'
                        : '${size.toStringAsFixed(1)}BB',
                    _gold,
                    () => _act('raise', raiseToBB: size),
                    s,
                  ),
                ),
                if (size != turn.suggestedRaiseToBB.last)
                  SizedBox(width: 8 * s),
              ],
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pot ${turn.potBB.toStringAsFixed(1)}BB'
          '${turn.toCallBB > 0 ? ' · ${turn.toCallBB.toStringAsFixed(1)}BB to call' : ''}',
          style: GoogleFonts.robotoMono(
              color: Colors.white.withOpacity(0.5), fontSize: 13 * s),
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            Expanded(
                child:
                    _actionButton('FOLD', _red, () => _act('fold'), s)),
            SizedBox(width: 8 * s),
            Expanded(
              child: turn.canCheck
                  ? _actionButton(
                      'CHECK', _accent, () => _act('check'), s)
                  : _actionButton(
                      'CALL', _accent, () => _act('call'), s),
            ),
            if (turn.canRaise) ...[
              SizedBox(width: 8 * s),
              Expanded(
                child: _actionButton('RAISE', _gold,
                    () => setState(() => _showRaiseSizes = true), s),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _actionButton(
      String label, Color color, VoidCallback onTap, double s) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14 * s),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.ibmPlexSans(
                  color: color,
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildHandOver(double s) {
    return GestureDetector(
      onTap: _nextHand,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(60),
        ),
        child: Center(
          child: Text('Next Hand',
              style: GoogleFonts.ibmPlexSans(
                  color: Colors.black,
                  fontSize: 17 * s,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _DrillChipFlight {
  final AnimationController controller;
  final Offset start;
  final Offset end;
  final Color color;
  final int seed;
  final int chipCount;

  const _DrillChipFlight({
    required this.controller,
    required this.start,
    required this.end,
    required this.color,
    required this.seed,
    required this.chipCount,
  });
}

class _DrillSummarySheet extends StatelessWidget {
  final List<DrillDecisionRecord> records;
  const _DrillSummarySheet({required this.records});

  @override
  Widget build(BuildContext context) {
    final correct =
        records.where((r) => r.result.grade == DrillGrade.correct).length;
    final ok = records.where((r) => r.result.grade == DrillGrade.ok).length;
    final mistakes = records
        .where((r) => r.result.grade == DrillGrade.mistake)
        .toList();
    final accuracy = records.isEmpty
        ? 0
        : ((correct + ok * 0.5) / records.length * 100).round();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Drill Summary',
                style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                _stat('Accuracy', '$accuracy%', const Color(0xFF54E98A)),
                _stat('Decisions', '${records.length}', Colors.white),
                _stat('Correct', '$correct', const Color(0xFF54E98A)),
                _stat('Close', '$ok', const Color(0xFFFFC857)),
                _stat('Mistakes', '${mistakes.length}',
                    const Color(0xFFE85D5D)),
              ],
            ),
            const SizedBox(height: 16),
            if (mistakes.isNotEmpty) ...[
              Text('WHERE YOU LEAKED',
                  style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: const Color(0xFF87ED81))),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: mistakes.length,
                  separatorBuilder: (_, __) => Container(
                      height: 1, color: const Color(0xFF1C1F21)),
                  itemBuilder: (context, i) {
                    final m = mistakes[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m.handClass} · ${m.position} · '
                            'you chose ${m.result.heroAction}, '
                            '${m.result.recommendedAction} was right',
                            style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.result.explanation,
                            style: GoogleFonts.ibmPlexSans(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                                height: 1.35),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Center(
                        child: Text('Keep Drilling',
                            style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Center(
                        child: Text('End Drill',
                            style: GoogleFonts.ibmPlexSans(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.robotoMono(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.4), fontSize: 11)),
        ],
      ),
    );
  }
}
