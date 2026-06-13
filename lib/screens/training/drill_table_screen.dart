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
    WidgetsBinding.instance.addPostFrameCallback((_) => _nextHand());
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

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              Expanded(child: _buildTable()),
              _buildHeroRow(),
              _buildRecentLines(),
              _buildBottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _records.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _confirmExit,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hand #${_engine.handNumber}',
                    style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${widget.stackBB.toInt()}BB · ${widget.seats.length}-handed',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          if (total > 0)
            GestureDetector(
              onTap: _showSummary,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  '$_correct/$total',
                  style: GoogleFonts.robotoMono(
                      color: _green,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Table ───────────────────────────────────────────────────────────

  Widget _buildTable() {
    final activeSeatMap = {
      for (final s in widget.seats) s.seatNumber: true,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Stack(
        key: _tableAreaKey,
        children: [
          PokerTableWidget(
            activeSeatMap: activeSeatMap,
            buttonPosition: _engine.handNumber > 0 ? _engine.buttonSeat : null,
            showDealerButton: _engine.handNumber > 0,
            showLogo: false,
            seatWidthFraction: 1.02,
            seatHeightFraction: 0.86,
            seatBuilder: (seatNumber, isActive) =>
                isActive ? _buildSeat(seatNumber) : const SizedBox.shrink(),
            centerContent: _buildPot(),
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

  Widget _buildPot() {
    if (_engine.handNumber == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('POT',
            style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        Text(
          '${(_lastUpdate?.potBB ?? _engine.potBB).toStringAsFixed(1)}BB',
          style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSeat(int seatNumber) {
    final seat =
        widget.seats.firstWhere((s) => s.seatNumber == seatNumber);
    final folded = _foldedSeats.contains(seatNumber);
    final action = _lastAction[seatNumber];
    final position = _engine.positionOf(seatNumber);
    final heroActing = seat.isHero && _phase == _Phase.acting;

    final name = seat.displayName.length > 8
        ? '${seat.displayName.substring(0, 7)}…'
        : seat.displayName;

    return Opacity(
      opacity: folded ? 0.35 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (position.isNotEmpty)
                  Text(
                    position,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Last action chip — keeps height stable so seats don't jump
          SizedBox(
            height: 16,
            child: action == null
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _actionColor(action).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        action,
                        style: GoogleFonts.robotoMono(
                          color: _actionColor(action),
                          fontSize: 9,
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

  // ── Chip flight animations ─────────────────────────────────────────

  void _fireChipFlight(int fromSeat, String action) {
    final renderBox =
        _tableAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final areaSize = renderBox.size;
    final seatPos = PokerTableWidget.getSeatPosition(
      fromSeat,
      areaSize,
      widthFraction: 1.02,
      heightFraction: 0.86,
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

  Widget _buildHeroRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final card in _engine.heroCards) ...[
            _buildCard(card),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          Text(_engine.heroHandClass,
              style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(_engine.heroPosition,
              style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.4), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCard(String card) {
    final suit = card.substring(card.length - 1);
    final rank = card.substring(0, card.length - 1);
    final isRed = suit == '♥' || suit == '♦';
    final color = isRed ? const Color(0xFFD32F2F) : Colors.black;
    return Container(
      width: 34,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank,
              style: GoogleFonts.robotoMono(
                  color: color, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(suit, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentLines() {
    final text = _handOverNote.isNotEmpty
        ? _handOverNote
        : _recentLines.isNotEmpty
            ? _recentLines.last
            : '';
    return SizedBox(
      height: 22,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.ibmPlexSans(
            color: _handOverNote.isNotEmpty
                ? _accent.withOpacity(0.85)
                : Colors.white.withOpacity(0.55),
            fontSize: 13,
            fontStyle:
                _handOverNote.isNotEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  // ── Bottom panel ────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: switch (_phase) {
        _Phase.feedback => _buildFeedback(),
        _Phase.acting => _buildActions(),
        _Phase.handOver => _buildHandOver(),
      },
    );
  }

  Widget _buildFeedback() {
    final grade = _lastGrade!;
    final (color, label) = switch (grade.grade) {
      DrillGrade.correct => (_green, 'CORRECT'),
      DrillGrade.ok => (_gold, 'CLOSE'),
      DrillGrade.mistake => (_red, 'MISTAKE'),
    };
    final diverge = !grade.linesAgree;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              const SizedBox(width: 8),
              Text('· you chose ${grade.heroAction}',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.45), fontSize: 12)),
              const Spacer(),
              Text(
                '${_engine.heroHandClass} = top ${grade.handTopPercent.round()}%',
                style: GoogleFonts.robotoMono(
                    color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
          if (diverge) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This lineup changes the play: GTO ${grade.gtoAction}s, exploit ${grade.exploitAction}s',
                style: GoogleFonts.ibmPlexSans(
                    color: _accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 10),
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
                  ),
                  const SizedBox(height: 8),
                  _evalRow(
                    'EXPLOIT',
                    _accent,
                    grade.exploitAction,
                    grade.exploitRangePercent,
                    grade.exploitReason,
                    highlight: diverge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _dismissFeedback,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                      fontSize: 15,
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
      {required bool highlight}) {
    final actionColor = switch (action) {
      'raise' => _gold,
      'call' || 'check' => _accent,
      _ => _red,
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlight ? _accent.withOpacity(0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
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
                width: 64,
                child: Text(tag,
                    style: GoogleFonts.ibmPlexSans(
                        color: tagColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
              Text(action.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(
                      color: actionColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (rangePercent > 0 && rangePercent < 100)
                Text('top ${rangePercent.round()}%',
                    style: GoogleFonts.robotoMono(
                        color: Colors.white.withOpacity(0.4), fontSize: 10)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(reason,
                style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
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
                      color: Colors.white.withOpacity(0.6), fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showRaiseSizes = false),
                child: Icon(Icons.close,
                    size: 18, color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  ),
                ),
                if (size != turn.suggestedRaiseToBB.last)
                  const SizedBox(width: 8),
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
              color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _actionButton('FOLD', _red, () => _act('fold'))),
            const SizedBox(width: 8),
            Expanded(
              child: turn.canCheck
                  ? _actionButton('CHECK', _accent, () => _act('check'))
                  : _actionButton('CALL', _accent, () => _act('call')),
            ),
            if (turn.canRaise) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton('RAISE', _gold,
                    () => setState(() => _showRaiseSizes = true)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.ibmPlexSans(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildHandOver() {
    return GestureDetector(
      onTap: _nextHand,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(60),
        ),
        child: Center(
          child: Text('Next Hand',
              style: GoogleFonts.ibmPlexSans(
                  color: Colors.black,
                  fontSize: 17,
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
