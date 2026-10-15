import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/buttons/glassy_icon_button.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../models/drill_models.dart';
import '../../services/analytics_service.dart';
import '../../services/challenge_sound_service.dart';
import '../../services/coach_persona.dart';
import '../../services/coach_level_resolver.dart';
import '../../services/coach_voice_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/daily_coach_lines_service.dart';
import '../../services/drill_engine.dart';
import '../../services/drill_insights.dart';
import '../../services/drill_range_lookup.dart';
import '../../widgets/coach_mascot.dart';
import '../../widgets/drill_range_chart_grid.dart';
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

  /// Daily Challenge mode: when [challengeConfig] is set, each of the
  /// [challengeDecisions] spots is a self-contained one-decision hand on
  /// its OWN per-spot seed (so the hero's action in one spot can never
  /// change another — the shared-puzzle guarantee). The run pops with the
  /// `List<DrillDecisionRecord>` and grading is the talking coach. Both
  /// null = normal endless drill (unchanged).
  final DailyChallengeConfig? challengeConfig;
  final int? challengeDecisions;

  const DrillTableScreen({
    super.key,
    required this.seats,
    required this.stackBB,
    this.anteMode = false,
    this.challengeConfig,
    this.challengeDecisions,
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

  late DrillEngine _engine;
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
  late Map<int, int> _visualSeatMap;

  _Phase _phase = _Phase.handOver;
  DrillHeroTurn? _heroTurn;
  DrillGradeResult? _lastGrade;
  DrillHandUpdate? _lastUpdate;
  bool _showRaiseSizes = false;

  int get _correct =>
      _records.where((r) => r.result.grade == DrillGrade.correct).length;

  bool get _isChallenge => widget.challengeDecisions != null;
  bool get _challengeDone =>
      _isChallenge && _records.length >= widget.challengeDecisions!;

  /// Coach voice mute state (challenge mode) — persisted preference.
  bool _voiceOn = true;

  /// Selected coach persona (challenge mode) — character leads + delivery.
  CoachPersona _persona = CoachPersonas.grinder;

  /// Player's coaching tier (challenge mode) — picks the AI line variant.
  CoachLevel _level = CoachLevel.beginner;

  /// AI-generated, level-adapted reason for the CURRENT spot (null until
  /// fetched, or when none exists → the persona template reason is used).
  String? _aiLine;

  /// Verdict suspense gate (challenge mode): the badge, colors, mascot
  /// reaction, haptic, progress dot, typed line and buttons all hold back
  /// until the coach "finishes evaluating" — i.e. the voice starts (text
  /// + voice land together), or the voice fails/is muted (grace/cap).
  bool _verdictRevealed = true;
  bool _sawVoiceLoading = false;
  Timer? _revealGrace;
  Timer? _revealCap;

  void _onSpeechState() {
    final state = CoachVoiceService.speechState.value;
    if (state == CoachSpeechState.loading) {
      _sawVoiceLoading = true;
    } else if (state == CoachSpeechState.speaking) {
      _revealVerdict();
    } else if (state == CoachSpeechState.idle &&
        _sawVoiceLoading &&
        !_verdictRevealed) {
      _revealVerdict(); // fetch failed or muted mid-flight — show it anyway
    }
  }

  void _armVerdictReveal() {
    _verdictRevealed = false;
    _sawVoiceLoading =
        CoachVoiceService.speechState.value == CoachSpeechState.loading;
    _revealGrace?.cancel();
    _revealCap?.cancel();
    // Grace: speak() flips to `loading` a few microtasks after the grade
    // lands; if it never does (voice muted/disabled), reveal after a
    // short deliberation beat so the suspense still reads.
    _revealGrace = Timer(const Duration(milliseconds: 600), () {
      if (!_sawVoiceLoading &&
          !_verdictRevealed &&
          mounted &&
          CoachVoiceService.speechState.value == CoachSpeechState.idle) {
        _revealVerdict();
      }
    });
    // Hard cap: a slow fetch never holds the verdict hostage.
    _revealCap = Timer(const Duration(seconds: 4), () {
      if (mounted) _revealVerdict();
    });
  }

  void _revealVerdict() {
    if (_verdictRevealed || !mounted) return;
    final grade = _lastGrade;
    setState(() => _verdictRevealed = true);
    if (grade == null) return;
    // Haptics + sound fire AT the reveal — they are a verdict spoiler
    // otherwise. Sound is challenge-only (free-play drills stay silent).
    switch (grade.grade) {
      case DrillGrade.correct:
        HapticFeedback.mediumImpact();
      case DrillGrade.ok:
        HapticFeedback.selectionClick();
      case DrillGrade.mistake:
        HapticFeedback.heavyImpact();
    }
    if (_isChallenge) {
      ChallengeSoundService.playVerdict(grade.grade);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.challengeDecisions != null) {
      // Deterministic insight rotation: with the seeded engine this makes
      // coach lines identical across users for the same actions, so the
      // shared neural-voice cache actually hits.
      DrillInsights.resetRotation();
      CoachVoiceService.loadEnabled().then((on) {
        if (mounted) setState(() => _voiceOn = on);
      });
      CoachPersonas.load().then((p) {
        if (mounted) setState(() => _persona = p);
      });
      CoachLevelResolver.resolveForCurrentUser().then((l) {
        if (mounted) _level = l;
      });
      CoachVoiceService.speechState.addListener(_onSpeechState);
    }
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
    if (_isChallenge) {
      CoachVoiceService.speechState.removeListener(_onSpeechState);
      CoachVoiceService.stop();
    }
    _revealGrace?.cancel();
    _revealCap?.cancel();
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
      final config = widget.challengeConfig;
      if (config != null) {
        // Daily Challenge: each spot is its own seeded one-decision hand.
        // _records.length = how many spots are already done = next index.
        final (engine, update) =
            DailyChallengeService.buildSpotEngine(config, _records.length);
        _engine = engine;
        _visualSeatMap = _buildVisualSeatMap();
        _consume(update);
      } else {
        _consume(_engine.startHand());
      }
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
      if (_isChallenge) {
        // Suspense: everything verdict-colored (badge, tint, mascot
        // reaction, haptic, dot) holds until the coach "finishes
        // evaluating" — see _armVerdictReveal/_revealVerdict.
        _armVerdictReveal();
        _aiLine = null;
        _speakCurrentGrade(update.grade!);
      }
    }

    if (update.awaitingHero) {
      _heroTurn = update.heroTurn;
      // Pause on feedback before the next decision in the same hand
      _phase = update.grade != null ? _Phase.feedback : _Phase.acting;
    } else if (update.handComplete) {
      _heroTurn = null;
      _phase = update.grade != null ? _Phase.feedback : _Phase.handOver;
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
    if (_isChallenge) CoachVoiceService.stop();
    // Challenge over: the Nth graded decision was just reviewed — hand the
    // records back to the Daily Challenge host, whatever state the hand is in.
    if (_challengeDone) {
      ChallengeSoundService.playComplete();
      Navigator.pop(
          context, List<DrillDecisionRecord>.unmodifiable(_records));
      return;
    }
    // Daily Challenge: exactly ONE graded decision per spot. After
    // reviewing it, always advance to the next spot's fresh engine — never
    // resume the same hand (a second decision would mis-align records and
    // the per-spot seeds; that caused the mid-run black screen).
    if (_isChallenge) {
      _nextHand();
      return;
    }
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

  Future<void> _confirmExit() async {
    if (_isChallenge) {
      // Abandoning mid-run records nothing — the day can be replayed fresh.
      Navigator.pop(context);
      return;
    }
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
              // Hero cards now live ON the hero seat, and the hand name +
              // villain context are folded into the bottom panel — so the
              // table flows straight into one clean panel instead of three
              // stacked blocks.
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
                Text(
                    _isChallenge
                        ? 'Daily Challenge'
                        : l10n.drillHandNumber(_engine.handNumber),
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
          if (_isChallenge)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The coach "watches" while it's your turn to act.
                if (_phase == _Phase.acting)
                  Padding(
                    padding: EdgeInsets.only(right: AppSpacing.xxs * s),
                    child: CoachMascot(
                      personaId: _persona.id,
                      expression: CoachExpression.idle,
                      size: 26 * s,
                    ),
                  ),
                _buildChallengeDots(s),
              ],
            )
          else if (total > 0)
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

  /// Challenge progress: one dot per decision, chess.com move-list style —
  /// green/gold/red once graded, outlined for the live spot, dim upcoming.
  Widget _buildChallengeDots(double s) {
    final total = widget.challengeDecisions!;
    // The freshest dot stays uncolored until the coach reveals the verdict
    // (the dot's color is a spoiler).
    final coloredCount =
        _verdictRevealed ? _records.length : _records.length - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: 5 * s),
          Container(
            width: 11 * s,
            height: 11 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < coloredCount
                  ? switch (_records[i].result.grade) {
                      DrillGrade.correct => _green,
                      DrillGrade.ok => _gold,
                      DrillGrade.mistake => _red,
                    }
                  : Colors.transparent,
              border: i >= coloredCount
                  ? Border.all(
                      color: i == coloredCount &&
                              (_phase == _Phase.acting ||
                                  !_verdictRevealed)
                          ? _accent
                          : AppColors.whiteOverlay(opacity: 0.25),
                      width: 1.5,
                    )
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  // ── Table ───────────────────────────────────────────────────────────

  // Seat fractions — the ellipse the pods are centered on. The neon table art
  // is drawn with BoxFit.contain (ratio 0.725), so the painted oval is
  // NARROWER than the old stretched SVG; pulling the seat ellipse in (esp.
  // horizontally) lands each pod ON the rail instead of hanging off the edge,
  // GGPoker/WPT-style. Side seats drove the old overflow, so width tightens
  // most.
  static const _seatW = 0.60;
  static const _seatH = 0.70;

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
    final heroActing = seat.isHero && _phase == _Phase.acting;
    final stackNow = _engine.stackOf(seatNumber);

    final name = seat.displayName.length > 8
        ? '${seat.displayName.substring(0, 7)}…'
        : seat.displayName;

    // Player node — WPT/888-style: a round silhouette avatar sitting ON the
    // rail, with a compact name + stack plate hanging OUTWARD from the oval
    // (so it never covers the felt). Position labels (BTN/SB/…) are dropped in
    // Daily Challenge; the dealer button + blind chips already convey
    // position and the plate reads cleaner as name + live stack. The whole
    // node breathes while it's the hero's turn. Top-of-table seats put the
    // plate ABOVE the avatar; everyone else below.
    final plateAbove = _chipDirection(visualSeat) == _ChipDir.down;
    Widget playerInfo = _playerNode(
      name: name,
      stack: stackNow,
      isHero: seat.isHero,
      heroActing: heroActing,
      plateAbove: plateAbove,
      s: s,
    );

    // Hero's hole cards live ON the hero seat (bottom-center), sitting just
    // above the avatar — so the player's hand reads right where they look to
    // act, and the bottom panel stays a single clean block (no separate
    // cards strip). New cards pop in each hand.
    if (seat.isHero) {
      playerInfo = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopIn(
            triggerKey: _engine.handNumber,
            duration: const Duration(milliseconds: 240),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _engine.heroCards.length; i++) ...[
                  if (i > 0) SizedBox(width: 3 * s),
                  _buildCard(_engine.heroCards[i], s),
                ],
              ],
            ),
          ),
          SizedBox(height: 3 * s),
          playerInfo,
        ],
      );
    }

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
              horizontal: 5.5 * s, vertical: 2 * s),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(
                AppDecorations.radiusSm),
            border: Border.all(color: pillColor.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: pillColor.withOpacity(0.28),
                blurRadius: 7,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Text(
            action,
            style: AppTypography.mono(
              color: pillColor,
              fontSize: 9 * s,
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

  /// WPT/888-style player node: a round silhouette avatar + a name/stack
  /// plate beneath it, with a small chip badge on the avatar. Hero gets an
  /// accent ring; the acting hero's node breathes. No position label.
  Widget _playerNode({
    required String name,
    required double stack,
    required bool isHero,
    required bool heroActing,
    required bool plateAbove,
    required double s,
  }) {
    final avatarR = 15.0 * s;
    final ringColor = heroActing
        ? _accent
        : isHero
            ? _accent.withOpacity(0.7)
            : AppColors.borderOnInverse;

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: avatarR * 2,
          height: avatarR * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgElevated,
            border: Border.all(color: ringColor, width: heroActing ? 2 : 1.5),
          ),
          child: Icon(
            Icons.person,
            size: avatarR * 1.15,
            color: isHero
                ? _accent.withOpacity(0.9)
                : AppColors.textSecondary.withOpacity(0.7),
          ),
        ),
        // Chip badge — small stacked-chip glyph on the avatar's lower-right,
        // echoing WPT's chip indicator.
        Positioned(
          right: -2 * s,
          bottom: -1 * s,
          child: Container(
            padding: EdgeInsets.all(2 * s),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgSurface,
              border: Border.all(color: AppColors.bgPrimary, width: 1),
            ),
            child: Icon(Icons.album, size: 7 * s, color: _accent),
          ),
        ),
      ],
    );

    final plate = Container(
      constraints: BoxConstraints(maxWidth: 74 * s),
      padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2.5 * s),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: Border.all(
          color: isHero ? _accent.withOpacity(0.55) : AppColors.bgElevated,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ibm(
              color: isHero ? _accent : AppColors.textPrimary,
              fontSize: 10 * s,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          AnimatedAmountText(
            value: stack,
            duration: const Duration(milliseconds: 260),
            formatter: (v) =>
                v <= 0.05 ? 'ALL-IN' : '${v.toStringAsFixed(1)} BB',
            style: AppTypography.mono(
              color: AppColors.textSecondary,
              fontSize: 9 * s,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    // Avatar overlaps the plate slightly (pod look). Plate hangs outward:
    // above the avatar for top-of-table seats, below for everyone else. The
    // node breathes while it's the acting hero's turn.
    final overlap = Transform.translate(
      offset: Offset(0, (plateAbove ? 4 : -4) * s),
      child: plate,
    );
    return PulseGlow(
      enabled: heroActing,
      color: _accent,
      borderRadius: BorderRadius.circular(avatarR),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: plateAbove ? [overlap, avatar] : [avatar, overlap],
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

  // ── Hero cards (rendered on the hero seat) ──────────────────────────

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
            _Phase.feedback => _isChallenge
                ? _buildCoachFeedback(s)
                : _buildFeedback(s, l10n),
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

  /// Fetch the AI reason for this spot (level + coach), then speak the
  /// composed line. The AI reason comes from the daily cache; on a miss
  /// (not generated yet, offline) the persona template reason is used.
  /// The fetch is quick and runs inside the existing "evaluating" beat.
  Future<void> _speakCurrentGrade(DrillGradeResult grade) async {
    final spotIndex = _records.length - 1; // this decision's index
    final ai = await DailyCoachLinesService.lineFor(
      spotIndex: spotIndex,
      coachId: _persona.id,
      level: _level,
    );
    if (!mounted || _phase != _Phase.feedback) return;
    if (ai != null) _aiLine = ai; // _coachLine now uses it
    // The coach speaks the same line the bubble types out (neural voice
    // only — quiet when unreachable).
    CoachVoiceService.speak(_coachLine(grade), coachId: _persona.id);
  }

  /// The one coach sentence for a grade — typed into the bubble AND spoken
  /// by the voice (kept identical so eyes and ears agree). The persona
  /// supplies the character lead; the AI reason (when present) replaces
  /// the template reason with the level-adapted explanation.
  String _coachLine(DrillGradeResult grade) =>
      _persona.compose(grade, _records.length, aiLine: _aiLine);

  void _toggleVoice() {
    HapticFeedback.selectionClick();
    setState(() => _voiceOn = !_voiceOn);
    CoachVoiceService.setEnabled(_voiceOn);
  }

  /// "Show range": the exact baseline chart this decision was graded
  /// against, with the hero's hand ringed on it.
  Future<void> _showRangeSheet() async {
    final ctx = _engine.lastGradedContext;
    if (ctx == null) return;
    HapticFeedback.selectionClick();
    final chart = DrillRangeLookup.chartFor(ctx);
    AnalyticsService.capture('daily_challenge_range_viewed', {
      'scenario': ctx.scenario.name,
      'position': ctx.positionGroup,
    });
    await AppSheet.show<void>(
      context: context,
      title: chart.title,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final layer in chart.layers) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (layer.kind) {
                      DrillRangeLayerKind.raise => AppColors.rangeRaise,
                      DrillRangeLayerKind.call => AppColors.rangeCall,
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text(layer.label,
                    style: AppTypography.ibm(
                        fontSize: 12, color: AppColors.textPrimary)),
                const SizedBox(width: AppSpacing.sm),
              ],
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accentPrimary, width: 2),
                ),
              ),
              const SizedBox(width: 4),
              Text('your hand',
                  style: AppTypography.ibm(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          DrillRangeChartGrid(
            chart: chart,
            highlightHand: _engine.heroHandClass,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(chart.caption,
              style: AppTypography.ibm(
                  fontSize: 11, color: AppColors.textDisabled)),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  /// Daily Challenge feedback: the coach "talks" — verdict badge pops in,
  /// then the explanation types out in a speech bubble (tap to skip ahead)
  /// while the voice reads it. English-only while the feature is
  /// admin-flagged (same as Leak Detector).
  Widget _buildCoachFeedback(double s) {
    final grade = _lastGrade!;
    final (verdictColor, label) = switch (grade.grade) {
      DrillGrade.correct => (_green, 'BEST MOVE'),
      DrillGrade.ok => (_gold, 'GOOD'),
      DrillGrade.mistake => (_red, 'LEAK'),
    };
    // Until the coach "finishes evaluating", NOTHING may leak the verdict:
    // the card stays neutral, the badge reads EVALUATING, the mascot holds
    // its idle face, and the action buttons wait.
    final revealed = _verdictRevealed;
    final color =
        revealed ? verdictColor : Colors.white.withValues(alpha: 0.45);
    final line = _coachLine(grade);
    final isLast = _challengeDone;
    // The mascot stands ON the feedback box, head breaking its top edge
    // (game-UI pop-out): the card is pushed down inside a Stack and the
    // reacting mascot is positioned over its top-left corner.
    final mascotSize = 62 * s;
    final mascotPop = 20 * s; // how far the head rises above the card
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          margin: EdgeInsets.only(top: mascotPop),
          padding: EdgeInsets.fromLTRB(AppSpacing.sm * s, AppSpacing.xxs * s,
              AppSpacing.sm * s, AppSpacing.sm * s),
          decoration: BoxDecoration(
            color: revealed
                ? verdictColor.withOpacity(0.08)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius:
                BorderRadius.circular(AppDecorations.radiusLg * s),
            border: Border.all(
                color: revealed
                    ? verdictColor.withOpacity(0.35)
                    : Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: verdict badge (or EVALUATING) + voice toggle. The
              // mascot pops out over the left, so clear its width first.
              Row(
                children: [
                  SizedBox(width: mascotSize + AppSpacing.xs * s),
                  if (revealed)
                    PopIn(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs * s, vertical: 4 * s),
                        decoration: BoxDecoration(
                          color: verdictColor,
                          borderRadius: BorderRadius.circular(
                              AppDecorations.pillRadius),
                        ),
                        child: Text(label,
                            style: AppTypography.ibm(
                                color: AppColors.textInverse,
                                fontSize: 12 * s,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0)),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs * s, vertical: 4 * s),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppDecorations.pillRadius),
                      ),
                      child: Text('EVALUATING…',
                          style: AppTypography.ibm(
                              color: AppColors.textSecondary,
                              fontSize: 12 * s,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0)),
                    ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleVoice,
                    child: Icon(
                      _voiceOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 18 * s,
                      color: _voiceOn
                          ? AppColors.accentPrimary
                          : AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
              // Second row: one clean context line — what you did vs the hand
              // strength. Replaces the old overloaded header (no truncation).
              Padding(
                padding: EdgeInsets.only(
                    left: mascotSize + AppSpacing.xs * s, top: 2 * s),
                child: Text(
                  'You ${grade.heroAction} · ${_engine.heroHandClass} · top ${grade.handTopPercent.round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono(
                      color: AppColors.textSecondary, fontSize: 11 * s),
                ),
              ),
          SizedBox(height: AppSpacing.xs * s),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.22),
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  // Invisible full text reserves the final layout so the
                  // card never jumps when the line reveals.
                  Opacity(
                    opacity: 0,
                    child: Text(line,
                        style: AppTypography.ibm(
                            color: AppColors.textPrimary,
                            fontSize: 14 * s,
                            height: 1.4)),
                  ),
                  if (revealed)
                    _TypedText(
                      // Keyed by decision count so each grade retypes.
                      key: ValueKey('coach_${_records.length}'),
                      text: line,
                      style: AppTypography.ibm(
                          color: AppColors.textPrimary,
                          fontSize: 14 * s,
                          height: 1.4),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          // Action buttons wait for the verdict too — skipping ahead of
          // the evaluation would defeat the suspense (max 4s).
          Opacity(
            opacity: revealed ? 1 : 0.15,
            child: IgnorePointer(
              ignoring: !revealed,
              child: Row(
            children: [
              GestureDetector(
                onTap: _showRangeSheet,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md * s,
                      vertical: AppSpacing.xs * s),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppDecorations.buttonRadius),
                    border: Border.all(color: color.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_on_rounded,
                          size: 14 * s, color: color),
                      SizedBox(width: 6 * s),
                      Text('Show range',
                          style: AppTypography.ibm(
                              color: color,
                              fontSize: 14 * s,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.xs * s),
              Expanded(
                child: GestureDetector(
                  onTap: _dismissFeedback,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(vertical: AppSpacing.xs * s),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(AppDecorations.buttonRadius),
                    ),
                    child: Center(
                      child: Text(
                        isLast ? 'See my result' : 'Next spot',
                        style: AppTypography.ibm(
                            color: AppColors.textInverse,
                            fontSize: 15 * s,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
        ],
      ),
        ),
        // The mascot holds its idle face while evaluating, then reacts
        // once at the reveal (bounce on BEST, head-shake on LEAK).
        Positioned(
          top: 0,
          left: AppSpacing.sm * s,
          child: CoachMascot(
            key: ValueKey('mascot_${_records.length}'),
            personaId: _persona.id,
            expression: revealed
                ? CoachMascot.expressionFor(grade.grade)
                : CoachExpression.idle,
            size: mascotSize,
          ),
        ),
        // "Coach is thinking…" dots while the verdict is held back.
        Positioned(
          top: 2,
          left: AppSpacing.sm * s + mascotSize - 6 * s,
          child: revealed
              ? const SizedBox.shrink()
              : _ThinkingDots(
                  size: 7 * s,
                  color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
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

/// Three staggered pulsing dots in a tiny speech bubble — the coach
/// "thinking before speaking" while the voice line is fetched. Mounted
/// only during [CoachSpeechState.loading], so the animation is bounded by
/// the fetch (8s + 8s timeouts worst case).
class _ThinkingDots extends StatefulWidget {
  final double size; // dot diameter
  final Color color;

  const _ThinkingDots({required this.size, required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: d, vertical: d * 0.8),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
        border: Border.all(color: widget.color.withOpacity(0.4)),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: d * 0.6),
              Opacity(
                opacity: 0.25 +
                    0.75 *
                        (0.5 + 0.5 * sin((_c.value * 2 * pi) - i * 0.9)),
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: widget.color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One-shot character-by-character reveal — the coach "speaking" in Daily
/// Challenge feedback. Tap anywhere on the text to skip to the full line.
/// No looping animation (battery rule); the controller runs once per text.
class _TypedText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TypedText({super.key, required this.text, required this.style});

  @override
  State<_TypedText> createState() => _TypedTextState();
}

class _TypedTextState extends State<_TypedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // ~18ms per character, capped so long coach lines don't drag.
    duration: Duration(
        milliseconds: (widget.text.length * 18).clamp(300, 1800)),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _controller.value = 1,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final chars =
              (widget.text.length * _controller.value).round();
          return Stack(
            children: [
              // Invisible full text reserves the final layout so the bubble
              // doesn't grow line-by-line while typing.
              Opacity(
                  opacity: 0,
                  child: Text(widget.text, style: widget.style)),
              Text(widget.text.substring(0, chars), style: widget.style),
            ],
          );
        },
      ),
    );
  }
}
