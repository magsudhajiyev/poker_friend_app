import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/drill_models.dart';
import '../../services/drill_engine.dart';

/// The drill loop: one preflop hand at a time against bots that play like
/// the user's real opponents, with instant exploit-based grading.
/// Nothing here persists — training is fully isolated from real data.
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

class _DrillTableScreenState extends State<DrillTableScreen> {
  static const _accent = Color(0xFF89F1EC);
  static const _gold = Color(0xFFFFC857);
  static const _red = Color(0xFFE85D5D);
  static const _green = Color(0xFF54E98A);

  late final DrillEngine _engine;
  final List<DrillEvent> _feed = [];
  final Set<int> _foldedSeats = {};
  final List<DrillDecisionRecord> _records = [];
  final ScrollController _feedScroll = ScrollController();

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
    _feedScroll.dispose();
    super.dispose();
  }

  // ── Drill flow ──────────────────────────────────────────────────────

  void _nextHand() {
    setState(() {
      _feed.clear();
      _foldedSeats.clear();
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
    _feed.addAll(update.newEvents);
    for (final e in update.newEvents) {
      if (e.action == 'folds') _foldedSeats.add(e.seat);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_feedScroll.hasClients) {
        _feedScroll.animateTo(
          _feedScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
              _buildSeatStrip(),
              const SizedBox(height: 8),
              _buildHeroCards(),
              const SizedBox(height: 8),
              Expanded(child: _buildFeed()),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

  Widget _buildSeatStrip() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.seats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final seat = widget.seats[i];
          final folded = _foldedSeats.contains(seat.seatNumber);
          final position = _positionOf(seat.seatNumber);
          return Opacity(
            opacity: folded ? 0.3 : 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: seat.isHero
                    ? _accent.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: seat.isHero
                      ? _accent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    seat.displayName,
                    style: GoogleFonts.ibmPlexSans(
                        color: seat.isHero ? _accent : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    position,
                    style: GoogleFonts.robotoMono(
                        color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _positionOf(int seatNumber) {
    for (final e in _feed) {
      if (e.seat == seatNumber) return e.position;
    }
    return seatNumber == _engine.heroSeat ? _engine.heroPosition : '·';
  }

  Widget _buildHeroCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final card in _engine.heroCards) ...[
          _buildCard(card),
          const SizedBox(width: 8),
        ],
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_engine.heroHandClass,
                style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text(_engine.heroPosition,
                style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.4), fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(String card) {
    final suit = card.substring(card.length - 1);
    final rank = card.substring(0, card.length - 1);
    final isRed = suit == '♥' || suit == '♦';
    return Container(
      width: 46,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank,
              style: GoogleFonts.robotoMono(
                  color: isRed ? const Color(0xFFD32F2F) : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          Text(suit,
              style: TextStyle(
                  color: isRed ? const Color(0xFFD32F2F) : Colors.black,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        controller: _feedScroll,
        itemCount: _feed.length + (_handOverNote.isNotEmpty ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _feed.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _handOverNote,
                style: GoogleFonts.ibmPlexSans(
                    color: _accent.withOpacity(0.8),
                    fontSize: 14,
                    fontStyle: FontStyle.italic),
              ),
            );
          }
          final e = _feed[i];
          final isHero = e.seat == _engine.heroSeat;
          final amount = e.toAmountBB != null
              ? ' to ${e.toAmountBB!.toStringAsFixed(1)}BB'
              : '';
          final isAggressive = e.action.contains('raise') ||
              e.action.contains('bet') ||
              e.action == 'jams';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(e.position,
                      style: GoogleFonts.robotoMono(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12)),
                ),
                Expanded(
                  child: Text(
                    '${e.name} ${e.action}$amount',
                    style: GoogleFonts.ibmPlexSans(
                      color: isHero
                          ? _accent
                          : isAggressive
                              ? _gold
                              : Colors.white.withOpacity(
                                  e.action == 'folds' ? 0.35 : 0.8),
                      fontSize: 14,
                      fontWeight:
                          isAggressive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.ibmPlexSans(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Text(
            grade.explanation,
            style: GoogleFonts.ibmPlexSans(
                color: Colors.white, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pot ${turn.potBB.toStringAsFixed(1)}BB'
              '${turn.toCallBB > 0 ? ' · ${turn.toCallBB.toStringAsFixed(1)}BB to call' : ''}',
              style: GoogleFonts.robotoMono(
                  color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
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
