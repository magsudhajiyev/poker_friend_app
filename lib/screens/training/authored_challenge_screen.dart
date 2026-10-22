import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/authored_tree.dart';
import '../../models/drill_models.dart';
import '../../services/analytics_service.dart';
import '../../services/authored_situation.dart';
import '../../services/authored_tree_walker.dart';
import '../../services/challenge_sound_service.dart';
import '../../services/coach_persona.dart';
import '../../services/coach_voice_service.dart';
import '../../widgets/authored_range_grid.dart';
import '../../widgets/coach_mascot.dart';
import '../../widgets/hand_micro_animations.dart';
import '../../widgets/poker_table_widget.dart';

/// AUTHORED TREE challenge runner — the hero plays a REAL solver game tree
/// (a solver export): at each node they pick any legal action, it is graded
/// against the solver's exact frequencies, and the villain (BTN) responds
/// deterministically from the data — so the hand genuinely branches on the
/// hero's choices, street by street, with the real board.
///
/// Returns the SAME `List<DrillDecisionRecord>` the RNG drill table does, so
/// the Daily Challenge host treats it identically (verdicts, streaks, coach
/// voice, share). The decision COUNT varies with the line taken.
class AuthoredChallengeScreen extends StatefulWidget {
  final AuthoredTree tree;
  final CoachPersona persona;

  /// 1-based position of this hand in the day, and the day's hand count
  /// (header "Hand 2/5"; last hand says "See result").
  final int handNumber;
  final int handCount;

  /// When set, a finished hand reports here instead of popping the route —
  /// the [AuthoredDayRunner] then shows the next hand.
  final void Function(AuthoredHandOutcome outcome)? onHandComplete;

  const AuthoredChallengeScreen({
    super.key,
    required this.tree,
    required this.persona,
    this.handNumber = 1,
    this.handCount = 1,
    this.onHandComplete,
  });

  @override
  State<AuthoredChallengeScreen> createState() =>
      _AuthoredChallengeScreenState();
}

/// One finished authored hand: its graded decisions and, aligned with them,
/// the pot (BB) at each decision — the accuracy weights (see DailyScoring) —
/// and the street label of each decision (results breakdown).
class AuthoredHandOutcome {
  final List<DrillDecisionRecord> records;
  final List<double> potWeights;
  final List<String> streets;
  final List<List<String>> boards;

  /// Per decision: what the hero faced, and plain-word labels for the hero's
  /// action and the solver's best action (results rows).
  final List<String> facing;
  final List<String> heroLabels;
  final List<String> bestLabels;
  const AuthoredHandOutcome(this.records, this.potWeights, this.streets,
      this.boards, this.facing, this.heroLabels, this.bestLabels);
}

/// Plays the day's authored hands back to back in ONE route: each hand is a
/// fresh [AuthoredChallengeScreen] (new key → clean state). Pops the list of
/// outcomes when the last hand ends; closing mid-day pops null (abandoned —
/// nothing is recorded, same rule as the RNG run).
class AuthoredDayRunner extends StatefulWidget {
  final List<AuthoredTree> trees;
  final CoachPersona persona;
  const AuthoredDayRunner(
      {super.key, required this.trees, required this.persona});

  @override
  State<AuthoredDayRunner> createState() => _AuthoredDayRunnerState();
}

class _AuthoredDayRunnerState extends State<AuthoredDayRunner> {
  final List<AuthoredHandOutcome> _outcomes = [];
  int _hand = 0;

  void _onHandComplete(AuthoredHandOutcome outcome) {
    _outcomes.add(outcome);
    if (_hand + 1 >= widget.trees.length) {
      Navigator.pop(context, List<AuthoredHandOutcome>.unmodifiable(_outcomes));
      return;
    }
    setState(() => _hand++);
  }

  @override
  Widget build(BuildContext context) => AuthoredChallengeScreen(
        key: ValueKey(_hand),
        tree: widget.trees[_hand],
        persona: widget.persona,
        handNumber: _hand + 1,
        handCount: widget.trees.length,
        onHandComplete: _onHandComplete,
      );
}

enum _Phase { acting, feedback }

/// How a table seat is drawn: the hero, the highlighted villain, a still-live
/// player yet to act, or a folded player (greyed out).
enum _SeatState { hero, villain, live, folded }

class _AuthoredChallengeScreenState extends State<AuthoredChallengeScreen> {
  static const _green = AppColors.accentPrimary;
  // Design tokens (no hardcoded hex): villain/GOOD gold, LEAK red.
  static const _gold = AppColors.warningAmber;
  static const _red = AppColors.accentDanger;

  final List<DrillDecisionRecord> _records = [];

  /// Pot (BB) and street label at each graded decision, aligned with
  /// [_records].
  final List<double> _potWeights = [];
  final List<String> _streets = [];
  final List<List<String>> _boards = [];
  final List<String> _facing = [];
  final List<String> _heroLabels = [];
  final List<String> _bestLabels = [];

  bool get _lastHand => widget.handNumber >= widget.handCount;
  int _index = 0; // decisions made so far (persona lead rotation + numbering)
  _Phase _phase = _Phase.acting;
  DrillGradeResult? _lastGrade;
  bool _voiceOn = true;

  /// The game-tree walker: current node, grading, deterministic villain.
  late final AuthoredTreeWalker _walker = AuthoredTreeWalker(widget.tree);

  /// The node the hero LAST acted on (for the feedback table + range sheet,
  /// since the walker has already advanced past it).
  TreeNode? _lastGradedNode;

  /// Villain moves auto-played after the hero's last action — shown as the
  /// incoming bet/check chips when the next decision renders.
  List<VillainMove> _pendingVillainMoves = const [];

  /// When the hero's chosen action had no solved continuation, the hand was
  /// kept alive via this solver-line action (shown as a note in feedback).
  AuthoredAction? _lastReroute;

  /// The action the hero committed on the current decision (null while acting)
  /// — drives the chip/tag shown at the hero seat after they act.
  AuthoredAction? _heroActionTaken;

  /// Hero's last committed action, kept while the street doesn't change (so
  /// the preflop open chip stays visible while facing the 3-bet, etc.).
  ({TreeStreet street, String tag, double amountBB})? _heroCommitted;

  /// Every action taken so far (hero + auto-played villain), in order — the
  /// coach narrates the new part of it before each hero decision.
  final List<SituationStep> _history = [];

  /// Hero + villain stacks after every action so far (chips in front of a
  /// seat have left its stack).
  ({double hero, double villain}) get _stacks =>
      AuthoredSituation.stacks(_tree.stackBB, _history);

  /// The coach's setup line for the current hero decision (acting phase).
  Situation? _situation;

  // Verdict suspense: hold the reveal until the coach voice starts (or fails).
  bool _verdictRevealed = true;
  bool _sawVoiceLoading = false;
  Timer? _revealGrace;
  Timer? _revealCap;

  AuthoredTree get _tree => widget.tree;

  /// Whether the hand has ended (checked at feedback time — the walker has
  /// already advanced past the graded node).
  bool get _done => _walker.isOver;

  /// The node the TABLE renders: the live node while acting, the just-graded
  /// node during feedback (board/pot must not jump ahead of the reveal).
  TreeNode get _displayNode => _phase == _Phase.acting
      ? _walker.current!
      : (_lastGradedNode ?? _walker.current!);

  @override
  void initState() {
    super.initState();
    // Load the saved coach-voice toggle (defaults on) — same as the RNG
    // challenge. Without this the voice may be gated off by the service's
    // persisted `_enabled`.
    CoachVoiceService.loadEnabled().then((on) {
      if (mounted) setState(() => _voiceOn = on);
    });
    CoachVoiceService.speechState.addListener(_onVoiceState);
    // Some trees open on a VILLAIN node (e.g. the hero flats a CO open — the
    // root is the CO's open, not the hero). Auto-play those villain nodes so
    // the walker lands on the hero's first real decision before we render /
    // explain the spot. Hero-root trees (hero opens) are a no-op here.
    if (!_walker.isHeroTurn && !_walker.isOver) {
      _walker.advanceVillains();
      _pendingVillainMoves = List.of(_walker.lastVillainMoves);
    }
    _explainSpot();
    AnalyticsService.capture('daily_challenge_authored_started', {
      'spot_id': _tree.id,
    });
  }

  @override
  void dispose() {
    _revealGrace?.cancel();
    _revealCap?.cancel();
    CoachVoiceService.speechState.removeListener(_onVoiceState);
    CoachVoiceService.stop();
    super.dispose();
  }

  // ── Decision handling ──────────────────────────────────────────────────
  void _act(AuthoredAction action) {
    if (_phase != _Phase.acting || !_walker.isHeroTurn) return;
    HapticFeedback.selectionClick();
    final node = _walker.current!;
    _lastGradedNode = node;
    // Results labels — computed from the history BEFORE this action.
    final firstIn = _history.isEmpty;
    _facing.add(AuthoredSituation.facingLabel(_tree, _history, node.street));
    _heroLabels
        .add(AuthoredSituation.actionLabel(action, node, firstIn: firstIn));
    // Walker grades against the node's solver frequencies, applies the
    // action, and auto-plays the villain's deterministic response(s).
    final grade = _walker.applyHeroAction(action);
    _pendingVillainMoves = List.of(_walker.lastVillainMoves);
    _lastReroute = _walker.lastReroute;
    // History follows the line the hand actually took (the reroute action
    // when the chosen one had no solved continuation).
    final taken = _lastReroute ?? action;
    _history.add(SituationStep(
      actor: TreeActor.hero,
      action: taken,
      sizeBB: switch (taken) {
        AuthoredAction.call => node.toCallBB,
        AuthoredAction.raise => node.sizingBB[AuthoredAction.raise] ?? 0,
        AuthoredAction.allin =>
          node.sizingBB[AuthoredAction.allin] ?? _tree.stackBB,
        _ => 0,
      },
      street: node.street,
    ));
    for (final m in _pendingVillainMoves) {
      _history.add(SituationStep(
        actor: TreeActor.villain,
        action: m.action,
        sizeBB: m.sizeBB,
        street: m.street,
      ));
    }
    _potWeights.add(node.potBB);
    _streets.add(_streetLabel(node.street));
    _boards.add(List<String>.of(node.board));
    final best = AuthoredAction.values.firstWhere(
        (a) => a.wire == grade.recommendedAction,
        orElse: () => action);
    _bestLabels
        .add(AuthoredSituation.actionLabel(best, node, firstIn: firstIn));
    _records.add(DrillDecisionRecord(
      handNumber: _index + 1,
      handClass: _tree.heroHandClass,
      position: _tree.heroPosition,
      scenario: DrillScenario.vsRaise, // nominal; not used by the host
      result: grade,
    ));
    // Record the hero's committed action so a chip/tag shows at their seat —
    // and remember it per-street so the chip survives into the next decision
    // on the same street (e.g. the preflop open while facing the 3-bet).
    _heroActionTaken = action;
    _heroCommitted = (
      street: node.street,
      tag: switch (action) {
        AuthoredAction.fold => 'Fold',
        AuthoredAction.check => 'Check',
        AuthoredAction.call => 'Call',
        AuthoredAction.raise => 'Raise',
        AuthoredAction.allin => 'All-in',
      },
      amountBB: switch (action) {
        AuthoredAction.call => node.toCallBB,
        AuthoredAction.raise => node.sizingBB[AuthoredAction.raise] ?? 0,
        AuthoredAction.allin =>
          node.sizingBB[AuthoredAction.allin] ?? _tree.stackBB,
        _ => 0,
      },
    );
    setState(() {
      _index++;
      _lastGrade = grade;
      _phase = _Phase.feedback;
    });
    // The verdict melody + reveal are HELD until the coach voice starts (or
    // the grace window elapses) — so the cue lands WITH the verdict, not
    // ahead of the voice.
    _armVerdictReveal();
    _speak(grade);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_done) {
      final outcome = AuthoredHandOutcome(
        List<DrillDecisionRecord>.unmodifiable(_records),
        List<double>.unmodifiable(_potWeights),
        List<String>.unmodifiable(_streets),
        List<List<String>>.unmodifiable(_boards),
        List<String>.unmodifiable(_facing),
        List<String>.unmodifiable(_heroLabels),
        List<String>.unmodifiable(_bestLabels),
      );
      if (!_lastHand && widget.onHandComplete != null) {
        // Next hand: its own setup line replaces this clip (no stop() —
        // stopping here raced the next speak() and silenced it).
        widget.onHandComplete!(outcome);
        return;
      }
      // Only cut the voice when LEAVING the challenge.
      CoachVoiceService.stop();
      ChallengeSoundService.playComplete();
      if (widget.onHandComplete != null) {
        widget.onHandComplete!(outcome);
      } else {
        Navigator.pop(context, outcome);
      }
      return;
    }
    setState(() {
      _phase = _Phase.acting;
      _lastGrade = null;
      _heroActionTaken = null;
      // When the hand continued via the solver's line (the chosen action had
      // no solved branch), the table story follows THAT action from here.
      final reroute = _lastReroute;
      final graded = _lastGradedNode;
      if (reroute != null && graded != null) {
        _heroCommitted = (
          street: graded.street,
          tag: switch (reroute) {
            AuthoredAction.fold => 'Fold',
            AuthoredAction.check => 'Check',
            AuthoredAction.call => 'Call',
            AuthoredAction.raise => 'Raise',
            AuthoredAction.allin => 'All-in',
          },
          amountBB: switch (reroute) {
            AuthoredAction.call => graded.toCallBB,
            AuthoredAction.raise => graded.sizingBB[AuthoredAction.raise] ?? 0,
            AuthoredAction.allin =>
              graded.sizingBB[AuthoredAction.allin] ?? _tree.stackBB,
            _ => 0,
          },
        );
      }
      _lastReroute = null;
      // Clear the hero's committed chip when the street moved on.
      final node = _walker.current;
      if (node != null &&
          _heroCommitted != null &&
          _heroCommitted!.street != node.street) {
        _heroCommitted = null;
      }
    });
    _explainSpot();
  }

  /// The coach sets up the spot BEFORE the hero decides: what just happened
  /// and what they face now. Shown in the bubble and spoken (replacing the
  /// previous verdict clip). Seeing a new spot with no context was confusing.
  void _explainSpot() {
    final node = _walker.current;
    if (node == null || !node.isHero) return;
    final situation = AuthoredSituation.describe(
        tree: _tree, node: node, history: _history, coachId: widget.persona.id);
    setState(() => _situation = situation);
    CoachVoiceService.speak(_situation!.spoken, coachId: widget.persona.id);
  }

  // ── Coach voice + verdict reveal ───────────────────────────────────────
  // Mirrors the RNG challenge's proven pattern: the verdict (badge, melody,
  // haptic) is held until the coach voice STARTS — text + voice land together.
  // Guards make sure it never hangs: a 600ms grace reveals when the voice is
  // muted/disabled, and a 4s hard cap reveals even if a fetch is slow.

  void _speak(DrillGradeResult grade) {
    // speak() self-guards on the enabled flag; calling it is safe either way.
    // The bubble shows the real cards ('9♠ 9♥'); the voice says the class
    // ('99' → "pocket nines").
    final line = widget.persona
        .compose(grade, _index)
        .replaceAll(_tree.heroCards.join(' '), _tree.heroHandClass);
    CoachVoiceService.speak(line, coachId: widget.persona.id);
  }

  void _armVerdictReveal() {
    _verdictRevealed = false;
    _sawVoiceLoading =
        CoachVoiceService.speechState.value == CoachSpeechState.loading;
    _revealGrace?.cancel();
    _revealCap?.cancel();
    // speak() flips to `loading` a few microtasks after the grade lands; if it
    // never does (voice muted/disabled), reveal after a short beat.
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

  void _onVoiceState() {
    final state = CoachVoiceService.speechState.value;
    if (state == CoachSpeechState.loading) {
      _sawVoiceLoading = true;
    } else if (state == CoachSpeechState.speaking) {
      _revealVerdict();
    } else if (state == CoachSpeechState.idle &&
        _sawVoiceLoading &&
        !_verdictRevealed) {
      _revealVerdict(); // fetch failed or muted mid-flight — show anyway
    }
  }

  void _revealVerdict() {
    _revealGrace?.cancel();
    _revealCap?.cancel();
    if (_verdictRevealed || !mounted) return;
    final grade = _lastGrade;
    setState(() => _verdictRevealed = true);
    if (grade == null) return;
    // Melody + haptic fire AT the reveal (they're a verdict spoiler otherwise).
    HapticFeedback.mediumImpact();
    ChallengeSoundService.playVerdict(grade.grade);
  }

  // ── Show range ─────────────────────────────────────────────────────────
  Future<void> _showRange() async {
    HapticFeedback.selectionClick();
    // The sheet shows the node the hero JUST acted on (the walker has
    // already advanced past it).
    final d = _lastGradedNode ?? _displayNode;
    // Build the per-hand MIX: hand → {action: freq}. This drives the split-
    // cell grid (each cell shows the real solver frequencies).
    final mix = <String, Map<AuthoredAction, double>>{};
    d.freq.forEach((action, grid) {
      grid.forEach((hand, f) {
        if (f > 0) (mix[hand] ??= {})[action] = f;
      });
    });
    // Which actions are present → the filter chips (fixed display order).
    const order = [
      AuthoredAction.raise,
      AuthoredAction.allin,
      AuthoredAction.call,
      AuthoredAction.check,
      AuthoredAction.fold,
    ];
    final actions = [
      for (final a in order)
        if (d.freq.containsKey(a)) a
    ];
    await AppSheet.show<void>(
      context: context,
      title:
          '${_streetLabel(d.street)} · ${_tree.heroPosition} vs ${_tree.villainPosition}',
      scrollable: true,
      body: _RangeSheetBody(
        mix: mix,
        actions: actions,
        highlightHand: _tree.heroHandClass,
        caption: 'Solver ranges · ${_bbCaps(_tree.formatLabel)}',
      ),
    );
  }

  String _streetLabel(TreeStreet s) => switch (s) {
        TreeStreet.preflop => 'Preflop',
        TreeStreet.flop => 'Flop',
        TreeStreet.turn => 'Turn',
        TreeStreet.river => 'River',
      };

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _header(l10n),
            Expanded(child: _table()),
            _bottom(l10n),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                      widget.handCount > 1
                          ? 'Hand ${widget.handNumber}/${widget.handCount} · '
                              '${_bbCaps(_tree.title)}'
                          : _bbCaps(_tree.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ibm(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  Text(_bbCaps(_tree.formatLabel),
                      style: AppTypography.ibm(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(_voiceOn ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white),
              onPressed: () {
                setState(() => _voiceOn = !_voiceOn);
                // Persist to the service — speak() gates on this flag, so the
                // toggle must flip it (not just the local bool).
                CoachVoiceService.setEnabled(_voiceOn);
                if (!_voiceOn) CoachVoiceService.stop();
              },
            ),
          ],
        ),
      );

  /// Progress dots. The decision count depends on the line taken, so dots
  /// grow as the hand plays: one colored dot per graded decision, plus a
  /// white "current" dot while the hand is live.
  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final r in _records)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (r.result.grade) {
                    DrillGrade.correct => _green,
                    DrillGrade.ok => _gold,
                    DrillGrade.mistake => _red,
                  },
                ),
              ),
            ),
          if (!_done)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: SizedBox(
                width: 9,
                height: 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ),
        ],
      );

  // Full 9-max MTT table. The HERO sits bottom-centre (visual seat 5); the
  // other 8 positions wrap around the oval clockwise in betting order so the
  // dealer button (BTN) and blinds read naturally. The seat→position map is
  // DERIVED from THIS spot's hero position (not hardcoded), so the hero's
  // label, the villain's seat, and the dealer button all match the real spot
  // — e.g. a BTN-vs-SB hand puts the button on the hero, a BTN-vs-CO hand
  // puts the hero on the button while the CO sits to their right.
  static const int _heroVisual = 5;

  /// Canonical 9-max order, clockwise from the button.
  static const List<String> _positionOrder = [
    'BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'LJ', 'HJ', 'CO',
  ];

  /// Visual seats laid out clockwise starting at the hero (bottom-centre).
  static const List<int> _clockwiseVisual = [5, 6, 7, 8, 9, 1, 2, 3, 4];

  /// visual seat (1..9) → position label, rotated so the hero's real position
  /// lands on seat 5 and the rest follow in betting order around the oval.
  late final Map<int, String> _seatPositions = _buildSeatPositions();

  Map<int, String> _buildSeatPositions() {
    final heroPos = _tree.heroPosition;
    var start = _positionOrder.indexOf(heroPos);
    if (start < 0) start = _positionOrder.indexOf('LJ'); // defensive fallback
    final map = <int, String>{};
    for (var i = 0; i < 9; i++) {
      final pos = _positionOrder[(start + i) % 9];
      map[_clockwiseVisual[i]] = pos;
    }
    return map;
  }

  /// The visual seat holding the real dealer button (whoever is 'BTN').
  int get _buttonVisual =>
      _seatPositions.entries.firstWhere((e) => e.value == 'BTN').key;

  /// The visual seat holding the villain (the spot's villainPosition).
  int get _villainVisual => _seatPositions.entries
      .firstWhere((e) => e.value == _tree.villainPosition,
          orElse: () => MapEntry(_buttonVisual, 'BTN'))
      .key;

  Widget _table() {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xs),
        _dots(),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final s = (constraints.maxWidth / 390).clamp(0.85, 1.25);
            final areaW = constraints.maxWidth - 2 * AppSpacing.xs * s;
            // The table box is no taller than the oval + seats need, and it
            // sits at the TOP of the area — spare height goes below it.
            final boxH = math.min(constraints.maxHeight, areaW * 1.45);
            final (seatW, seatH) = _seatRing(Size(areaW, boxH), s);
            // Usable felt width inside the neon rail (rail ≈ 64% of the
            // painted oval's width, minus a margin) — the board must fit it.
            final (paintedW, _) = PokerTableWidget.containedSeatFractions(
                Size(areaW, boxH), _tableW, _tableH);
            final feltW = areaW * paintedW * 0.64 * 0.9;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs * s),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: Image.asset('assets/icons/Table bg_small.png',
                        fit: BoxFit.cover),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: areaW,
                      height: boxH,
                      child: PokerTableWidget(
                        activeSeatMap: {
                          for (var v = 1; v <= 9; v++) v: true,
                        },
                        buttonPosition: _buttonVisual,
                        showDealerButton: true,
                        showLogo: false,
                        tableWidthFraction: _tableW,
                        tableHeightFraction: _tableH,
                        seatWidthFraction: seatW,
                        seatHeightFraction: seatH,
                        seatBuilder: (visualSeat, isActive) {
                          if (!isActive) return const SizedBox.shrink();
                          if (visualSeat == _heroVisual) return _heroSeat(s);
                          final pos = _seatPositions[visualSeat] ?? '';
                          final isVillain = visualSeat == _villainVisual;
                          return _seatNode(pos, isVillain, s);
                        },
                        centerContent: _centerContent(s, feltW),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  static const double _tableW = 0.85;
  static const double _tableH = 0.8;

  /// Seat-ring fractions that put every seat plate just OUTSIDE the neon
  /// rail. The rail sits at ~62% (x) / ~81% (y) of the table art's half-size
  /// (measured on table_neon_clean.png); a plate centred on the old fixed
  /// ring straddled the rail, and the folded (translucent) right-hand seats
  /// showed the rail through them. Clamped so plates and the hero's taller
  /// cards+plate column stay inside the area on narrow phones.
  (double, double) _seatRing(Size area, double s) {
    final (pw, ph) =
        PokerTableWidget.containedSeatFractions(area, _tableW, _tableH);
    final railRx = area.width * pw / 2 * 0.64;
    final railRy = area.height * ph / 2 * 0.82;
    final plateHalfW = 30 * s;
    final plateHalfH = 20 * s;
    final gap = 8 * s; // diagonal seats sit closer to a curved rail
    final rx = math.min(railRx + plateHalfW + gap, area.width / 2 - plateHalfW);
    final ry = math.min(railRy + plateHalfH + gap, area.height / 2 - 48 * s);
    return (2 * rx / area.width, 2 * ry / area.height);
  }

  /// Board (grows street by street) + pot, centred on the felt. No floating
  /// prompt — the chips in front of each seat tell the story of the action.
  Widget _centerContent(double s, double feltW) {
    final d = _displayNode;
    // Card scale: the flop keeps its size (1.05·s); a longer board (turn,
    // river) shrinks every card just enough that the row fits the felt.
    // A card is 34 wide + 5 of gap at scale 1 (see _card).
    final n = d.board.length;
    final fit = n == 0 ? 1.05 * s : feltW / n / (34 + 5);
    final cardScale = math.min(1.05 * s, fit);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (d.board.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in d.board)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.5 * cardScale),
                  child: _card(c, cardScale),
                ),
            ],
          )
        else
          Text('PREFLOP',
              style: AppTypography.ibm(
                  fontSize: 11 * s,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.textSecondary)),
        SizedBox(height: 6 * s),
        Text('Pot ${_fmtBB(d.potBB)}BB',
            style: AppTypography.mono(
                fontSize: 13 * s,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ],
    );
  }

  /// A compact bet chip shown between a seat and the felt: a small coloured
  /// dot (the "chips") + the amount, with the action word kept small. Reads as
  /// a physical bet sitting in front of the player rather than a big label.
  Widget _betChip(String tag, double amountBB, Color color, double s) {
    final hasAmount = amountBB > 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.9), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 4 * s,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chip dot
          Container(
            width: 7 * s,
            height: 7 * s,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: 4 * s),
          if (hasAmount)
            Text('${_fmtBB(amountBB)}BB',
                style: AppTypography.mono(
                    fontSize: 10 * s,
                    fontWeight: FontWeight.w700,
                    color: Colors.white))
          else if (tag.isNotEmpty)
            Text(tag,
                style: AppTypography.ibm(
                    fontSize: 9.5 * s,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
        ],
      ),
    );
  }

  /// Big blinds always read 'BB' — tree titles/labels authored earlier say
  /// '70bb', so normalize data text at display time.
  static String _bbCaps(String text) =>
      text.replaceAllMapped(RegExp(r'(\d)bb\b'), (m) => '${m[1]}BB');

  String _fmtBB(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  Widget _heroSeat(double s) {
    // Chip in front of the hero: their committed action on THIS street —
    // kept visible across decisions on the same street (e.g. the preflop
    // open while facing the 3-bet).
    final (tag, amount) = _heroChip();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hero's bet chip sits ABOVE the cards (toward the felt).
        if (tag.isNotEmpty || amount > 0) ...[
          _betChip(tag, amount, _green, s),
          SizedBox(height: 3 * s),
        ],
        PopIn(
          triggerKey: _tree.id,
          duration: const Duration(milliseconds: 240),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _tree.heroCards.length; i++) ...[
                if (i > 0) SizedBox(width: 3 * s),
                _card(_tree.heroCards[i], 0.88 * s),
              ],
            ],
          ),
        ),
        SizedBox(height: 3 * s),
        _plate(_tree.heroPosition,
            stackBB: _stacks.hero, state: _SeatState.hero, s: s),
      ],
    );
  }

  /// (tag, amount) for the hero's chip at the display node: the committed
  /// action on this street (which IS the just-taken action during feedback).
  (String, double) _heroChip() {
    final committed = _heroCommitted;
    if (committed == null) return ('', 0.0);
    if (committed.street != _displayNode.street) return ('', 0.0);
    return (committed.tag, committed.amountBB);
  }

  /// A non-hero seat: the still-live villain (BTN) or a folded player. The
  /// villain shows the bet chip they're facing the hero with.
  Widget _seatNode(String position, bool isVillain, double s) {
    // Villain's chip: their latest auto-played move on the DISPLAYED street
    // (e.g. the 3-bet the hero is facing, the flop c-bet, or a Check tag).
    final move = _villainMoveOnStreet(_displayNode.street);
    final (vTag, vAmount) = move == null
        ? ('', 0.0)
        : (
            switch (move.action) {
              AuthoredAction.check => 'Check',
              AuthoredAction.call => 'Call',
              AuthoredAction.fold => 'Fold',
              AuthoredAction.raise => 'Bet',
              AuthoredAction.allin => 'All-in',
            },
            move.sizeBB,
          );
    final showChip = isVillain && (vTag.isNotEmpty || vAmount > 0);
    final plate = _plate(
      position,
      stackBB: isVillain ? _stacks.villain : _tree.stackBB,
      state: _seatStateFor(position, isVillain),
      s: s,
    );
    if (!showChip) return plate;
    // Villain's chip sits BELOW the plate (toward the felt, since villain is
    // at the top of the oval).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        plate,
        SizedBox(height: 3 * s),
        _betChip(vTag, vAmount, _gold, s),
      ],
    );
  }

  /// These are heads-up postflop solver spots: only the hero and the villain
  /// reach the flop — every OTHER seat folded preflop. So all non-hero,
  /// non-villain seats render greyed ("folded"); the villain stays highlighted
  /// until (if) it folds to end the hand.
  _SeatState _seatStateFor(String position, bool isVillain) {
    if (isVillain) {
      final villainFolded = _done &&
          _pendingVillainMoves.isNotEmpty &&
          _pendingVillainMoves.last.action == AuthoredAction.fold;
      return villainFolded ? _SeatState.folded : _SeatState.villain;
    }
    return _SeatState.folded;
  }

  /// The villain's most recent auto-played move on [street], if any.
  VillainMove? _villainMoveOnStreet(TreeStreet street) {
    for (final m in _pendingVillainMoves.reversed) {
      if (m.street == street) return m;
    }
    return null;
  }

  /// How the hand ended (shown under the coach line on the final verdict).
  String? _outcomeLine() {
    if (!_done) return null;
    if (_heroActionTaken == AuthoredAction.fold) {
      return 'You fold — ${_tree.villainPosition} takes the pot.';
    }
    final last = _pendingVillainMoves.isNotEmpty
        ? _pendingVillainMoves.last.action
        : null;
    if (last == AuthoredAction.fold) {
      return '${_tree.villainPosition} folds — you take the pot.';
    }
    return 'Hand complete — showdown.';
  }

  Widget _plate(String name,
      {required double stackBB, required _SeatState state, required double s}) {
    final folded = state == _SeatState.folded;
    final hero = state == _SeatState.hero;
    final borderColor = switch (state) {
      _SeatState.hero => _green,
      _SeatState.villain => _gold,
      _SeatState.live => Colors.white.withValues(alpha: 0.25),
      _SeatState.folded => Colors.white.withValues(alpha: 0.10),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: folded ? 0.4 : 1.0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 3 * s),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          border: Border.all(
              color: borderColor,
              width: hero || state == _SeatState.villain ? 1.2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hero ? 'You · $name' : name,
                style: AppTypography.ibm(
                    fontSize: 10.5 * s,
                    fontWeight: hero ? FontWeight.w700 : FontWeight.w500,
                    color: hero
                        ? _green
                        : (state == _SeatState.villain
                            ? _gold
                            : Colors.white))),
            Text(folded ? 'folded' : '${_fmtBB(stackBB)}BB',
                style: AppTypography.mono(
                    fontSize: 9.5 * s, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _bottom(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.acting:
        return _actions(l10n);
      case _Phase.feedback:
        return _feedback(l10n);
    }
  }

  Widget _actions(AppLocalizations l10n) {
    final d = _walker.current!;
    // Design-system pills (AppButton) — not range-chart colours: Fold is
    // the quiet outlined button, Check/Call the neutral white one, the
    // aggressive Bet/Raise the primary green, All-in the destructive red.
    // One shared height so a two-line label (amount) never makes a button
    // taller than its neighbours.
    final btnHeight =
        (MediaQuery.sizeOf(context).height * 0.062).clamp(48.0, 58.0);
    Widget btn((String, String) label, AppButtonVariant variant,
            VoidCallback onTap) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: btnHeight,
              child: AppButton(
                label: label.$1,
                subLabel: label.$2,
                variant: variant,
                fullWidth: true,
                onTap: onTap,
              ),
            ),
          ),
        );

    // Labels carry the real solver sizes; on preflop the hero's 'raise' may
    // be an open or a 4-bet — the sizing map knows the to-amount. A raise
    // with no size and check available is a synthetic test "Bet".
    final isBetContext = d.actions.contains(AuthoredAction.check);

    /// (action word, amount) — amount is '' when the action has none.
    (String, String) labelFor(AuthoredAction a) {
      final size = d.sizingBB[a];
      String amt(double? v) => v == null ? '' : '${_fmtBB(v)}BB';
      return switch (a) {
        AuthoredAction.fold => ('Fold', ''),
        AuthoredAction.check => ('Check', ''),
        AuthoredAction.call => ('Call', d.toCallBB > 0 ? amt(d.toCallBB) : ''),
        AuthoredAction.raise => (isBetContext ? 'Bet' : 'Raise', amt(size)),
        AuthoredAction.allin => ('All-in', amt(size)),
      };
    }

    AppButtonVariant variantFor(AuthoredAction a) => switch (a) {
          AuthoredAction.fold => AppButtonVariant.secondaryLarge,
          AuthoredAction.check => AppButtonVariant.white,
          AuthoredAction.call => AppButtonVariant.white,
          AuthoredAction.raise => AppButtonVariant.primaryLarge,
          AuthoredAction.allin => AppButtonVariant.destructive,
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_situation != null) ...[
            _situationBubble(_situation!.text),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            children: [
              for (final a in _displayActions(d))
                btn(labelFor(a), variantFor(a), () => _act(a)),
            ],
          ),
        ],
      ),
    );
  }

  /// The coach's pre-decision setup: mascot + what happened + what the hero
  /// faces. Neutral tint — the verdict colors belong to the feedback phase.
  /// The mascot is larger than the card and is pinned ABOVE its top edge, so
  /// it always breaks out of the border whatever the text length (the card's
  /// text column reserves its width). The top margin keeps the overflow
  /// clear of the table.
  Widget _situationBubble(String text) {
    final mascot = (MediaQuery.sizeOf(context).width * 0.2).clamp(68.0, 92.0);
    final overflow = mascot * 0.3; // how far the coach pokes above the card
    return Padding(
      padding: EdgeInsets.only(top: overflow),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: mascot - overflow),
            padding: EdgeInsets.fromLTRB(mascot + AppSpacing.xs, AppSpacing.xs,
                AppSpacing.sm, AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                text,
                key: ValueKey(text),
                style: AppTypography.ibm(
                    fontSize: 13.5, height: 1.35, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xxs,
            top: -overflow,
            child: CoachMascot(
              personaId: widget.persona.id,
              expression: CoachExpression.idle,
              size: mascot,
            ),
          ),
        ],
      ),
    );
  }

  /// The buttons shown for a hero node. The solver sometimes offers only
  /// check(/jam) when its strategy is a pure check — but a TRAINER must still
  /// let the player try the wrong aggressive move, so a synthetic Bet (raise)
  /// is added whenever check is available without one. It grades off the real
  /// frequencies (0% → leak) and the hand then continues along the solver's
  /// main branch.
  List<AuthoredAction> _displayActions(TreeNode d) {
    final list = List<AuthoredAction>.of(d.actions);
    if (list.contains(AuthoredAction.check) &&
        !list.contains(AuthoredAction.raise)) {
      // Insert the Bet between check and all-in (display order).
      final allinIdx = list.indexOf(AuthoredAction.allin);
      list.insert(
          allinIdx == -1 ? list.length : allinIdx, AuthoredAction.raise);
    }
    return list;
  }

  Widget _feedback(AppLocalizations l10n) {
    final grade = _lastGrade!;
    final revealed = _verdictRevealed;
    final (color, label) = switch (grade.grade) {
      DrillGrade.correct => (_green, 'BEST MOVE'),
      DrillGrade.ok => (_gold, 'GOOD'),
      DrillGrade.mistake => (_red, 'LEAK'),
    };
    final expression = revealed
        ? CoachMascot.expressionFor(grade.grade)
        : CoachExpression.idle;

    // The WHOLE coach section is tinted by the verdict (green/gold/red) —
    // neutral while still "evaluating" so the color doesn't spoil the verdict.
    final sectionColor =
        revealed ? color : Colors.white.withValues(alpha: 0.45);
    // Same coach treatment as the pre-decision bubble: a bigger mascot
    // pinned above the card's top edge so it breaks out of the border.
    final mascot = (MediaQuery.sizeOf(context).width * 0.2).clamp(68.0, 92.0);
    final overflow = mascot * 0.3;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.sm, overflow, AppSpacing.sm, AppSpacing.md),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: revealed ? 0.1 : 0.04),
              borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
              border: Border.all(
                  color: sectionColor.withValues(alpha: revealed ? 0.4 : 0.18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  // Text column reserves the mascot's width; min height so the
                  // card is never shorter than the mascot's visible part.
                  constraints: BoxConstraints(minHeight: mascot - overflow),
                  padding: EdgeInsets.only(left: mascot),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (revealed) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(
                                      AppDecorations.pillRadius),
                                ),
                                child: Text(label,
                                    style: AppTypography.ibm(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Colors.black)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.persona.compose(grade, _index),
                                style: AppTypography.ibm(
                                    fontSize: 14,
                                    height: 1.35,
                                    color: Colors.white),
                              ),
                              if (_lastReroute != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'The hand continues along the solver line — '
                                  '${switch (_lastReroute!) {
                                    AuthoredAction.check => 'check',
                                    AuthoredAction.call => 'call',
                                    AuthoredAction.raise => 'raise',
                                    AuthoredAction.allin => 'all-in',
                                    AuthoredAction.fold => 'fold',
                                  }}.',
                                  style: AppTypography.ibm(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                              if (_done && _outcomeLine() != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _outcomeLine()!,
                                  style: AppTypography.ibm(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ] else
                              Text('Evaluating…',
                                  style: AppTypography.ibm(
                                      fontSize: 14,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (revealed)
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Show range',
                          // Same range-grid icon as the RNG challenge.
                          leadingIcon: const Icon(Icons.grid_on_rounded,
                              size: 16, color: Colors.white),
                          variant: AppButtonVariant.secondaryLarge,
                          fullWidth: true,
                          onTap: _showRange,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          // Same hand across decisions → just "Next" (not "Next
                          // spot", which implies a brand-new hand).
                          label: !_done
                              ? 'Next'
                              : (_lastHand ? 'See result' : 'Next hand'),
                          variant: AppButtonVariant.primaryLarge,
                          fullWidth: true,
                          onTap: _next,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.xxs,
            top: -overflow,
            child: CoachMascot(
              personaId: widget.persona.id,
              expression: expression,
              size: mascot,
            ),
          ),
        ],
      ),
    );
  }

  /// Card face — same glyph format + styling as the drill table's _buildCard.
  Widget _card(String card, double s) {
    final suit = card.substring(card.length - 1);
    final rank = card.substring(0, card.length - 1);
    final red = suit == '♥' || suit == '♦';
    return Container(
      width: 34 * s,
      height: 46 * s,
      decoration: BoxDecoration(
        color: AppColors.bgInverse,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm * 0.75 * s),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank,
              style: AppTypography.mono(
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w700,
                  color: red ? _red : Colors.black)),
          Text(suit,
              style: TextStyle(
                  fontSize: 15 * s, color: red ? _red : Colors.black)),
        ],
      ),
    );
  }
}

/// Range-sheet body: a MIXED-frequency 13×13 grid (each cell split by the
/// solver's per-action shares) + tappable action filter chips.
/// Tapping a chip shows ONLY that action's share per cell; tap again / "All"
/// shows the full mix.
class _RangeSheetBody extends StatefulWidget {
  final Map<String, Map<AuthoredAction, double>> mix;
  final List<AuthoredAction> actions; // present actions, display order
  final String highlightHand;
  final String caption;

  const _RangeSheetBody({
    required this.mix,
    required this.actions,
    required this.highlightHand,
    required this.caption,
  });

  @override
  State<_RangeSheetBody> createState() => _RangeSheetBodyState();
}

class _RangeSheetBodyState extends State<_RangeSheetBody> {
  AuthoredAction? _filter; // null = show full mix

  static Color _colorFor(AuthoredAction a) => switch (a) {
        AuthoredAction.raise => AppColors.rangeRaise,
        AuthoredAction.allin => AppColors.rangeAllIn,
        AuthoredAction.call => AppColors.rangeCall,
        AuthoredAction.check => AppColors.accentPrimary,
        AuthoredAction.fold => AppColors.rangeFold,
      };

  static String _label(AuthoredAction a) => switch (a) {
        AuthoredAction.raise => 'Raise',
        AuthoredAction.allin => 'All-in',
        AuthoredAction.call => 'Call',
        AuthoredAction.check => 'Check',
        AuthoredAction.fold => 'Fold',
      };

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, AuthoredAction? action) {
      final selected = _filter == action;
      final color =
          action == null ? AppColors.accentPrimary : _colorFor(action);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _filter = selected ? null : action);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.22)
                  : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              border: Border.all(
                  color:
                      selected ? color : Colors.white.withValues(alpha: 0.12),
                  width: selected ? 1.4 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action != null) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(label,
                    style: AppTypography.ibm(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('All', null),
              for (final a in widget.actions) chip(_label(a), a),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentPrimary, width: 2),
              ),
            ),
            const SizedBox(width: 4),
            Text('your hand',
                style: AppTypography.ibm(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AuthoredRangeGrid(
          mix: widget.mix,
          highlightHand: widget.highlightHand,
          filter: _filter,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(widget.caption,
            style:
                AppTypography.ibm(fontSize: 11, color: AppColors.textDisabled)),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
