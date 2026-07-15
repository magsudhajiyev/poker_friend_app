import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/buttons/glassy_icon_button.dart';
import '../../design_system/components/sheets/app_sheet.dart';
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
  final bool anteMode;

  const DrillTableScreen({
    super.key,
    required this.seats,
    required this.stackBB,
    this.anteMode = false,
  });

  @override
  State<DrillTableScreen> createState() => _DrillTableScreenState();
}

enum _Phase { acting, feedback, handOver }

/// Direction to offset the action pill from the seat toward the table center.
enum _ChipDir { up, down, left, right }

class _DrillTableScreenState extends State<DrillTableScreen>
    with TickerProviderStateMixin {
  static const _accent = AppColors.accentPrimary;
  static const _gold = Color(0xFFFFC857);
  static const _red = Color(0xFFE85D5D);
  static const _green = AppColors.accentPrimary;
  static const _chipWhite = Color(0xFFCCCCCC);

  late final DrillEngine _engine;
  final Set<int> _foldedSeats = {};
  final Map<int, String> _lastAction = {}; // seat -> compact action label
  final List<String> _recentLines = []; // newest last, capped
  final List<DrillDecisionRecord> _records = [];

  // Action ripple: each batch of engine events is revealed in order around
  // the table (one step apart) instead of appearing all at once.
  static const _rippleStepMs = 55;
  int _batchId = 0;
  final Map<int, int> _actionStamp = {}; // seat -> batch that last acted
  final Map<int, int> _actionDelayMs = {}; // seat -> entrance delay in batch

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
    _engine = DrillEngine(
        seats: widget.seats,
        stackBB: widget.stackBB,
        anteMode: widget.anteMode);
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
      _actionStamp.clear();
      _actionDelayMs.clear();
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
    _batchId++;
    // Collect seats that need chip flights this batch, with their ripple slot
    final flightQueue = <(int seat, String action, int order)>[];

    var order = 0;
    for (final e in update.newEvents) {
      if (e.action == 'folds') _foldedSeats.add(e.seat);
      _lastAction[e.seat] = _actionLabel(e);
      _actionStamp[e.seat] = _batchId;
      _actionDelayMs[e.seat] = order * _rippleStepMs;
      if (!e.action.startsWith('posts')) {
        final amount = e.toAmountBB != null
            ? ' to ${e.toAmountBB!.toStringAsFixed(1)}BB'
            : '';
        _recentLines.add('${e.name} (${e.position}) ${e.action}$amount');
        if (_recentLines.length > 3) _recentLines.removeAt(0);
      }

      // Queue chip flight for money actions (not folds/checks)
      if (e.action != 'folds' && e.action != 'checks') {
        flightQueue.add((e.seat, e.action, order));
      }
      order++;
    }

    // Fire chip flights after the frame so layout positions are valid,
    // staggered to match each seat's slot in the action ripple. The hand
    // token guards against a flight landing after "Next hand" was tapped.
    if (flightQueue.isNotEmpty) {
      final handToken = _engine.handNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final (seat, action, ord) in flightQueue) {
          Future.delayed(Duration(milliseconds: ord * _rippleStepMs), () {
            if (mounted && _engine.handNumber == handToken) {
              _fireChipFlight(seat, action);
            }
          });
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
          Future.delayed(const Duration(milliseconds: 700), () {
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
    final update = _lastUpdate;
    if (update != null &&
        update.handComplete &&
        !update.awaitingHero &&
        update.reachedFlop) {
      // Hand went to flop — preflop drill is done, auto-advance
      _nextHand();
      return;
    }
    setState(() {
      _phase = (update?.awaitingHero ?? false)
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
    final leave = await AppSheet.show<bool>(
      context: context,
      title: AppLocalizations.of(context).drillSummaryTitle,
      heightFraction: 0.75,
      scrollable: false,
      body: _DrillSummarySheet(records: _records),
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
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(s, l10n),
              Expanded(child: _buildTable(s, l10n)),
              _buildHeroRow(s),
              _buildRecentLines(s),
              _buildBottomPanel(s, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double s, AppLocalizations l10n) {
    final total = _records.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md * s, 10 * s, AppSpacing.md * s, AppSpacing.xxxs * s),
      child: Row(
        children: [
          GlassyIconButton(
            icon: Icons.close,
            size: 36 * s,
            iconSize: 20 * s,
            onPressed: _confirmExit,
          ),
          SizedBox(width: AppSpacing.xs * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.drillHandNumber(_engine.handNumber),
                    style: AppTypography.ibm(
                        color: AppColors.textPrimary,
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w600)),
                Text(
                  l10n.drillHandedLabel(widget.stackBB.toInt(), widget.seats.length),
                  style: AppTypography.ibm(
                      color: AppColors.textSecondary,
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
                    horizontal: AppSpacing.xs * s,
                    vertical: 6 * s),
                decoration: BoxDecoration(
                  color: AppColors.whiteOverlay(opacity: 0.08),
                  borderRadius: BorderRadius.circular(
                      AppDecorations.pillRadius),
                ),
                child: Text(
                  '$_correct/$total',
                  style: AppTypography.mono(
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

  // Seat fractions — sized so seats + action pills fit inside the dotted grid.
  // Keep conservative to prevent side-seat pills from overflowing the container.
  static const _seatW = 0.72;
  static const _seatH = 0.64;

  Widget _buildTable(double s, AppLocalizations l10n) {
    // Build active seat map using visual positions
    final activeSeatMap = {
      for (final seat in widget.seats) _visualSeatMap[seat.seatNumber]!: true,
    };
    // Map dealer button to its visual position
    final visualButton = _engine.handNumber > 0
        ? _visualSeatMap[_engine.buttonSeat]
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs * s, vertical: AppSpacing.xxxs * s),
      child: Stack(
        key: _tableAreaKey,
        clipBehavior: Clip.hardEdge,
        children: [
          // Dotted background grid
          Positioned.fill(
            child: Image.asset(
              'assets/icons/Table bg_small.png',
              fit: BoxFit.cover,
            ),
          ),
          PokerTableWidget(
            activeSeatMap: activeSeatMap,
            buttonPosition: visualButton,
            showDealerButton: _engine.handNumber > 0,
            showLogo: false,
            seatWidthFraction: _seatW,
            seatHeightFraction: _seatH,
            seatBuilder: (visualSeat, isActive) =>
                isActive ? _buildSeat(_actualSeat(visualSeat), s) : const SizedBox.shrink(),
            centerContent: _buildPot(s, l10n),
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

  Widget _buildPot(double s, AppLocalizations l10n) {
    if (_engine.handNumber == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.drillPot,
            style: AppTypography.ibm(
                color: AppColors.textSecondary,
                fontSize: 11 * s,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        // Rolls between values and pulses when the pot grows
        AnimatedAmountText(
          value: _lastUpdate?.potBB ?? _engine.potBB,
          duration: const Duration(milliseconds: 300),
          pulseOnIncrease: true,
          formatter: (v) => '${v.toStringAsFixed(1)}BB',
          style: AppTypography.mono(
              color: AppColors.textPrimary,
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
    final stackNow = _engine.stackOf(seatNumber);

    final name = seat.displayName.length > 8
        ? '${seat.displayName.substring(0, 7)}…'
        : seat.displayName;

    // Player info pill: name + position·stack, wrapped in a breathing glow
    // while it's the hero's turn to act.
    final playerInfo = PulseGlow(
      enabled: heroActing,
      color: _accent,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs * s, vertical: AppSpacing.xxxs * s),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: heroActing
                ? _accent
                : seat.isHero
                    ? _accent.withOpacity(0.55)
                    : AppColors.bgElevated,
            width: heroActing ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              style: AppTypography.ibm(
                color: seat.isHero ? _accent : AppColors.textPrimary,
                fontSize: 13 * s,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            // Position + live stack (rolls down as chips go in)
            AnimatedAmountText(
              value: stackNow,
              duration: const Duration(milliseconds: 260),
              formatter: (v) {
                final stackText =
                    v <= 0.05 ? 'ALL-IN' : v.toStringAsFixed(1);
                return position.isEmpty
                    ? stackText
                    : '$position · $stackText';
              },
              style: AppTypography.mono(
                color: AppColors.textSecondary,
                fontSize: 10 * s,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    // Action/bet pill — solid base + colored glow so it pops off the felt,
    // entering in its ripple slot (staggered per batch of actions).
    Widget? statusPill;
    if (action != null) {
      final pillColor = _actionColor(action);
      statusPill = PopIn(
        triggerKey: '${_actionStamp[seatNumber]}|$action',
        delay: Duration(milliseconds: _actionDelayMs[seatNumber] ?? 0),
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 7 * s, vertical: 2.5 * s),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(
                AppDecorations.radiusSm),
            border: Border.all(color: pillColor.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: pillColor.withOpacity(0.28),
                blurRadius: 9,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Text(
            action,
            style: AppTypography.mono(
              color: pillColor,
              fontSize: 10 * s,
              fontWeight: FontWeight.w700,
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

    // Folds ease out (dim + slight shrink) instead of snapping
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      opacity: folded ? 0.35 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        scale: folded ? 0.94 : 1.0,
        child: content,
      ),
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
      duration: const Duration(milliseconds: 380),
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
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md * s, vertical: AppSpacing.xxxs * s),
      // New hole cards pop in with each hand
      child: PopIn(
        triggerKey: _engine.handNumber,
        duration: const Duration(milliseconds: 240),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final card in _engine.heroCards) ...[
              _buildCard(card, s),
              SizedBox(width: 6 * s),
            ],
            SizedBox(width: AppSpacing.xxs * s),
            Text(_engine.heroHandClass,
                style: AppTypography.mono(
                    color: AppColors.textPrimary,
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w600)),
            SizedBox(width: AppSpacing.xxs * s),
            Text(_engine.heroPosition,
                style: AppTypography.ibm(
                    color: AppColors.textSecondary,
                    fontSize: 13 * s)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String card, double s) {
    final suit = card.substring(card.length - 1);
    final rank = card.substring(0, card.length - 1);
    final isRed = suit == '♥' || suit == '♦';
    final color = isRed ? const Color(0xFFD32F2F) : AppColors.textInverse;
    return Container(
      width: 34 * s,
      height: 46 * s,
      decoration: BoxDecoration(
        color: AppColors.bgInverse,
        borderRadius: BorderRadius.circular(6 * s),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank,
              style: AppTypography.mono(
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            text,
            key: ValueKey(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ibm(
              color: _handOverNote.isNotEmpty
                  ? _accent.withOpacity(0.85)
                  : AppColors.textSecondary,
              fontSize: 13 * s,
              fontStyle: _handOverNote.isNotEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom panel ────────────────────────────────────────────────────

  Widget _buildBottomPanel(double s, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md * s, AppSpacing.xxs * s,
          AppSpacing.md * s, AppSpacing.md * s),
      // Phase changes slide-fade in (feedback card rising feels deliberate,
      // not popping) — keyed by phase + decision count so each new grade
      // animates even when the phase stays `feedback`.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 190),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey('$_phase|${_records.length}'),
          child: switch (_phase) {
            _Phase.feedback => _buildFeedback(s, l10n),
            _Phase.acting => _buildActions(s, l10n),
            _Phase.handOver => _buildHandOver(s, l10n),
          },
        ),
      ),
    );
  }

  Widget _buildFeedback(double s, AppLocalizations l10n) {
    final grade = _lastGrade!;
    final (color, label) = switch (grade.grade) {
      DrillGrade.correct => (_green, l10n.drillCorrect),
      DrillGrade.ok => (_gold, l10n.drillClose),
      DrillGrade.mistake => (_red, l10n.drillMistake),
    };
    final diverge = !grade.linesAgree;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.sm * s),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg * s),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(label,
                  style: AppTypography.ibm(
                      color: color,
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              SizedBox(width: AppSpacing.xxs * s),
              Text(l10n.drillYouChose(grade.heroAction),
                  style: AppTypography.ibm(
                      color: AppColors.textSecondary,
                      fontSize: 12 * s)),
              const Spacer(),
              Text(
                '${_engine.heroHandClass} = ${l10n.drillTopPercent(grade.handTopPercent.round())}',
                style: AppTypography.mono(
                    color: AppColors.textSecondary, fontSize: 11 * s),
              ),
            ],
          ),
          if (diverge) ...[
            SizedBox(height: AppSpacing.xxs * s),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs * s,
                  vertical: AppSpacing.xxxs * s),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(
                    AppDecorations.radiusSm * s),
              ),
              child: Text(
                l10n.drillLineupChanges(grade.gtoAction, grade.exploitAction),
                style: AppTypography.ibm(
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
                    l10n.drillGto,
                    AppColors.textSecondary,
                    grade.gtoAction,
                    grade.gtoRangePercent,
                    grade.gtoReason,
                    highlight: false,
                    s: s,
                    l10n: l10n,
                  ),
                  SizedBox(height: AppSpacing.xxs * s),
                  _evalRow(
                    l10n.drillExploit,
                    _accent,
                    grade.exploitAction,
                    grade.exploitRangePercent,
                    grade.exploitReason,
                    highlight: diverge,
                    s: s,
                    l10n: l10n,
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
              padding: EdgeInsets.symmetric(
                  vertical: AppSpacing.xs * s),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                    AppDecorations.buttonRadius),
              ),
              child: Center(
                child: Text(
                  (_lastUpdate?.awaitingHero ?? false)
                      ? l10n.drillContinue
                      : l10n.drillGotIt,
                  style: AppTypography.ibm(
                      color: AppColors.textInverse,
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
      {required bool highlight, required double s,
      required AppLocalizations l10n}) {
    final actionColor = switch (action) {
      'raise' => _gold,
      'call' || 'check' => _accent,
      _ => _red,
    };
    return Container(
      padding: EdgeInsets.all(AppSpacing.xxs * s),
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
                    style: AppTypography.ibm(
                        color: tagColor,
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
              Text(action.toUpperCase(),
                  style: AppTypography.ibm(
                      color: actionColor,
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (rangePercent > 0 && rangePercent < 100)
                Text(l10n.drillTopPercent(rangePercent.round()),
                    style: AppTypography.mono(
                        color: AppColors.textSecondary,
                        fontSize: 10 * s)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            SizedBox(height: 3 * s),
            Text(reason,
                style: AppTypography.ibm(
                    color: AppColors.contentActive.withOpacity(0.7),
                    fontSize: 12 * s,
                    height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(double s, AppLocalizations l10n) {
    final turn = _heroTurn;
    if (turn == null) return const SizedBox.shrink();

    if (_showRaiseSizes) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(l10n.drillRaiseTo,
                  style: AppTypography.ibm(
                      color: AppColors.textSecondary,
                      fontSize: 13 * s)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showRaiseSizes = false),
                child: Icon(Icons.close,
                    size: 18 * s, color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xxs * s),
          Row(
            children: [
              for (final size in turn.suggestedRaiseToBB) ...[
                Expanded(
                  child: _actionButton(
                    size >= turn.maxRaiseToBB
                        ? l10n.drillJam
                        : '${size.toStringAsFixed(1)}BB',
                    _gold,
                    () => _act('raise', raiseToBB: size),
                    s,
                  ),
                ),
                if (size != turn.suggestedRaiseToBB.last)
                  SizedBox(width: AppSpacing.xxs * s),
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
          '${l10n.drillPotLabel(turn.potBB.toStringAsFixed(1))}${turn.toCallBB > 0 ? ' · ${l10n.drillToCall(turn.toCallBB.toStringAsFixed(1))}' : ''}',
          style: AppTypography.mono(
              color: AppColors.textSecondary, fontSize: 13 * s),
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            Expanded(
                child:
                    _actionButton(l10n.drillFold, _red, () => _act('fold'), s)),
            SizedBox(width: AppSpacing.xxs * s),
            Expanded(
              child: turn.canCheck
                  ? _actionButton(
                      l10n.drillCheck, _accent, () => _act('check'), s)
                  : _actionButton(
                      l10n.drillCall, _accent, () => _act('call'), s),
            ),
            if (turn.canRaise) ...[
              SizedBox(width: AppSpacing.xxs * s),
              Expanded(
                child: _actionButton(l10n.drillRaise, _gold,
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
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm * s),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd * s),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.ibm(
                  color: color,
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildHandOver(double s, AppLocalizations l10n) {
    return GestureDetector(
      onTap: _nextHand,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm * s),
        decoration: BoxDecoration(
          color: AppColors.bgInverse,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        child: Center(
          child: Text(l10n.drillNextHand,
              style: AppTypography.ibm(
                  color: AppColors.textInverse,
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
    final l10n = AppLocalizations.of(context);
    final correct =
        records.where((r) => r.result.grade == DrillGrade.correct).length;
    final ok = records.where((r) => r.result.grade == DrillGrade.ok).length;
    final mistakes = records
        .where((r) => r.result.grade == DrillGrade.mistake)
        .toList();
    final accuracy = records.isEmpty
        ? 0
        : ((correct + ok * 0.5) / records.length * 100).round();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              children: [
                _stat(l10n.drillAccuracy, '$accuracy%', AppColors.accentPrimary),
                _stat(l10n.drillDecisions, '${records.length}',
                    AppColors.textPrimary),
                _stat(l10n.drillCorrectLabel, '$correct', AppColors.accentPrimary),
                _stat(l10n.drillCloseLabel, '$ok', AppColors.accentTertiary),
                _stat(l10n.drillMistakes, '${mistakes.length}',
                    AppColors.accentDanger),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (mistakes.isNotEmpty) ...[
              Text(l10n.drillWhereYouLeaked,
                  style: AppTypography.sectionHeader()),
              const SizedBox(height: AppSpacing.xxs),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: mistakes.length,
                  separatorBuilder: (_, __) => Container(
                      height: AppDecorations.borderThin,
                      color: AppColors.separatorDark),
                  itemBuilder: (context, i) {
                    final m = mistakes[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.drillMistakeDetail(m.handClass, m.position, m.result.heroAction, m.result.recommendedAction),
                            style: AppTypography.bodySmall(
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.result.explanation,
                            style: AppTypography.ibm(
                                color: AppColors.textSecondary,
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.drillKeepDrilling,
                    variant: AppButtonVariant.secondaryLarge,
                    fullWidth: true,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: l10n.drillEndDrill,
                    variant: AppButtonVariant.white,
                    fullWidth: true,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
          ),
        ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTypography.mono(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.bodyXsMedium(
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
