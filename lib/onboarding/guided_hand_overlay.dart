import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../models/poker_game_state.dart'; // PlayerAction, BettingRound
import 'onboarding_state.dart';
import 'onboarding_prefs.dart';
import 'onboarding_tour.dart'; // buildTooltip, createOnboardingCoachMark
import '../design_system/constants/decorations.dart';


// ---------------------------------------------------------------------------
// Gesture hint strings (localized)
// ---------------------------------------------------------------------------
String _gestureHint(AppLocalizations l10n, PlayerAction a) {
  switch (a) {
    case PlayerAction.fold:
      return l10n.guidedGestureFold;
    case PlayerAction.check:
      return l10n.guidedGestureCheck;
    case PlayerAction.call:
      return l10n.guidedGestureCall;
    case PlayerAction.bet:
      return l10n.guidedGestureBet;
    case PlayerAction.raise:
      return l10n.guidedGestureRaise;
    case PlayerAction.none:
      return '';
  }
}

String _actionLabel(AppLocalizations l10n, PlayerAction a) {
  switch (a) {
    case PlayerAction.fold:
      return l10n.guidedActionFold;
    case PlayerAction.check:
      return l10n.guidedActionCheck;
    case PlayerAction.call:
      return l10n.guidedActionCall;
    case PlayerAction.bet:
      return l10n.guidedActionBet;
    case PlayerAction.raise:
      return l10n.guidedActionRaise;
    case PlayerAction.none:
      return '';
  }
}

/// Floating instruction overlay for the guided example hand (Phase 4).
///
/// Reactive design: instructions adapt to the user's choices when it's their
/// turn, and script opponent actions to keep the hand moving logically.
class GuidedHandOverlay extends StatefulWidget {
  final GlobalKey gestureInfoKey;
  final GlobalKey? skipButtonKey;
  final GlobalKey? stackRingKey;
  final GlobalKey? tableButtonKey;
  final GlobalKey? blindsPillKey;
  final GlobalKey? nextHandButtonKey;
  final GlobalKey? sessionInfoButtonKey;
  final GlobalKey? menuButtonKey;
  final GlobalKey? drawingAreaKey;
  final GlobalKey? undoButtonKey;
  final int? heroSeat;
  final int currentPlayerSeat;
  final bool Function(PlayerAction) isValidAction;
  final BettingRound currentRound;
  /// Live getter for the current player seat (reads from gameState directly).
  /// Use this instead of [currentPlayerSeat] for decision-making after an
  /// action has been performed, since the widget param may be stale.
  final int Function()? liveCurrentPlayer;

  /// Called when the guided overlay skips or finishes, so the parent can
  /// rebuild (e.g. to hide the progress bar).
  final VoidCallback? onSkipOrFinish;

  /// Called when the tour needs a fresh hand dealt (between hand 1 and 2).
  final VoidCallback? onDealNextHand;

  /// Returns the GlobalKey for the first empty seat on the table (for the
  /// "Add Your Opponents" spotlight). Evaluated lazily at tour time.
  final GlobalKey? Function()? firstEmptySeatKey;

  /// Called after the user adds an opponent during the tour, so the parent
  /// can re-initialize the pot with the updated player configuration.
  final VoidCallback? onReinitializeHand;

  /// Returns the number of active (seated) players. Used to decide whether
  /// the "Add Opponents" step is needed after the drawing board intro.
  final int Function()? activePlayerCount;

  /// Returns true when the game state's betting round is complete.
  /// Used to decide whether to script the next opponent action or let
  /// the core auto-advance logic handle street transitions.
  final bool Function()? isBettingRoundComplete;

  const GuidedHandOverlay({
    super.key,
    required this.gestureInfoKey,
    this.skipButtonKey,
    this.stackRingKey,
    this.tableButtonKey,
    this.blindsPillKey,
    this.nextHandButtonKey,
    this.sessionInfoButtonKey,
    this.menuButtonKey,
    this.drawingAreaKey,
    this.undoButtonKey,
    this.heroSeat,
    this.currentPlayerSeat = 0,
    required this.isValidAction,
    required this.currentRound,
    this.liveCurrentPlayer,
    this.onSkipOrFinish,
    this.onDealNextHand,
    this.firstEmptySeatKey,
    this.onReinitializeHand,
    this.activePlayerCount,
    this.isBettingRoundComplete,
  });

  @override
  State<GuidedHandOverlay> createState() => GuidedHandOverlayState();
}

class GuidedHandOverlayState extends State<GuidedHandOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _gestureInfoShown = false;
  bool _preflopOpenerDone = false;
  bool _stackRingTourShown = false;
  bool _drawingBoardShown = false;
  bool _undoTourShown = false;
  int _actionsCompleted = 0; // count of guided actions done

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    if (OnboardingState.isGuidedHandActive) {
      if (OnboardingState.guidedHandPhase == GuidedPhase.gestureInfo) {
        // Show gesture info coach mark first
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showGestureInfoCoachMark();
        });
      } else {
        _animController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isHeroTurn {
    final current = widget.liveCurrentPlayer?.call() ?? widget.currentPlayerSeat;
    return widget.heroSeat != null && current == widget.heroSeat;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Called after a poker action is performed.
  void onActionPerformed(PlayerAction action) {
    if (!OnboardingState.isGuidedHandActive) return;
    _actionsCompleted++;

    final phase = OnboardingState.guidedHandPhase;

    if (phase == GuidedPhase.scriptedAction) {
      // A scripted action was completed — figure out what's next
      _advanceAfterScriptedAction(action);
    } else if (phase == GuidedPhase.heroTurn) {
      // Hero chose an action — set up the reactive response
      _advanceAfterHeroAction(action);
    }
  }

  /// Called after board cards dialog completes.
  void onBoardCardsDealt(BettingRound round) {
    if (!OnboardingState.isGuidedHandActive) return;
    if (OnboardingState.guidedHandPhase == GuidedPhase.boardCards) {
      // Board cards dealt — figure out who acts first on this street
      _startNewStreet();
    }
  }

  /// Called when a street auto-advances (betting round complete → nextStreet).
  void onStreetAdvance(BettingRound newRound) {
    if (!OnboardingState.isGuidedHandActive) return;
    // The board cards dialog will show — set phase to boardCards
    _setPhase(GuidedPhase.boardCards);
  }

  /// Called after hole cards dialog completes.
  void onHoleCardsCompleted() {
    // Second (free-play) tour hand just finished — spotlight the ⓘ button
    // so the user can return to Session Details and see their stack chart.
    if (OnboardingState.isOnboardingActive &&
        !OnboardingState.isReplay &&
        OnboardingState.currentPhase == 4 &&
        OnboardingState.secondTourHandPending) {
      OnboardingState.secondTourHandPending = false;
      _showReturnToDetailsCoachMark();
      return;
    }

    if (!OnboardingState.isGuidedHandActive) return;
    if (OnboardingState.guidedHandPhase == GuidedPhase.holeCards) {
      _setPhase(GuidedPhase.handComplete);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && OnboardingState.guidedHandPhase == GuidedPhase.handComplete) {
          // Hand 1 complete — show BB pill + Next Hand spotlights, then prompt hand 2.
          // Use post-frame callback so the widget tree has settled after setState
          // and the blinds pill / next hand button GlobalKeys have valid contexts.
          OnboardingState.guidedHandPhase = GuidedPhase.done;
          widget.onSkipOrFinish?.call();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showPostHandCoachMarks();
          });
        }
      });
    }
  }

  /// Called when the hand completes (auto or via winner dialog).
  void onHandComplete() {
    if (!OnboardingState.isGuidedHandActive) return;
    _actionsCompleted = 12; // Fill progress bar to 100%
    if (OnboardingState.guidedHandPhase.index < GuidedPhase.holeCards.index) {
      _setPhase(GuidedPhase.holeCards);
    }
  }

  /// Called when the user undoes the last action.
  void onActionUndone() {
    if (!OnboardingState.isGuidedHandActive) return;
    if (_actionsCompleted > 0) _actionsCompleted--;

    // After undo, currentPlayer is the player whose action was undone.
    // Re-evaluate whether it's the hero's turn or a scripted player's.
    if (_isHeroTurn) {
      _setPhase(GuidedPhase.heroTurn);
    } else {
      _determineNextScriptedAction();
    }
  }

  /// Skip the guided hand entirely.
  void skip() {
    _finishOnboarding();
    if (mounted) {
      _animController.reverse();
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Step 1: Gesture Info Coach Mark
  // ---------------------------------------------------------------------------

  void _showGestureInfoCoachMark() {
    if (!mounted) return;
    // Wait for gesture info key to attach
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (widget.gestureInfoKey.currentContext == null) {
        // Key not ready — just skip to overlay
        _gestureInfoShown = true;
        _startGuidedHand();
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'gesture_info',
          keyTarget: widget.gestureInfoKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 16,
          contents: [
            TargetContent(
              align: ContentAlign.left,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedGestureGuideTitle,
                  body: l10n.guidedGestureGuideBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      ];

      final coach = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        opacityShadow: 0.85,
        paddingFocus: 12,
        hideSkip: true,
        onFinish: () {
          _gestureInfoShown = true;
          _startGuidedHand();
        },
        onSkip: () {
          _gestureInfoShown = true;
          _startGuidedHand();
          return true;
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Start the actual guided hand after gesture info
  // ---------------------------------------------------------------------------

  void _startGuidedHand() {
    if (!mounted) return;
    _showDrawingBoardCoachMark();
  }

  /// Whether the overlay is waiting for the user to add an opponent before
  /// continuing to the drawing board intro.
  bool _waitingForOpponentAdd = false;

  void _showAddOpponentsCoachMark() {
    if (!mounted) return;

    _showAddOpponentsCoachMarkAttempt(0);
  }

  void _showAddOpponentsCoachMarkAttempt(int attempt) {
    if (!mounted) return;

    // Try to find an empty seat key, with retries
    final seatKey = widget.firstEmptySeatKey?.call();
    final hasContext = seatKey != null && seatKey.currentContext != null;
    if (!hasContext && attempt < 5) {
      // Retry after next frame (seats may not have rendered yet)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddOpponentsCoachMarkAttempt(attempt + 1);
      });
      return;
    }

    // Use the empty seat key if available, otherwise fall back to table button
    final targetKey = hasContext ? seatKey! : widget.tableButtonKey;
    if (targetKey == null || targetKey.currentContext == null) {
      // No valid target at all — skip to scripted hand
      _beginScriptedHand();
      return;
    }

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'add_opponents',
        keyTarget: targetKey,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 14,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.guidedAddOpponentsTitle,
                body: l10n.guidedAddOpponentsBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 12,
      hideSkip: true,
      onFinish: () {
        // Coach mark dismissed — now the user can tap any seat to add an
        // opponent. We wait for the callback from [onOpponentAdded] before
        // continuing to the drawing board.
        _waitingForOpponentAdd = true;
      },
      onSkip: () {
        _beginScriptedHand();
        return true;
      },
    );
    coach.show(context: context);
  }

  /// Called by the poker hand screen after the SeatConfigSheet closes and
  /// an opponent was added. Re-initializes the hand with the new player
  /// configuration, shows stack ring instruction, then begins the scripted hand.
  void onOpponentAdded({GlobalKey? addedSeatKey}) {
    if (!_waitingForOpponentAdd) return;
    _waitingForOpponentAdd = false;
    // Re-initialize pot/blinds with the updated player configuration
    widget.onReinitializeHand?.call();
    // Show stack ring instruction for the newly added opponent
    _showStackAdjustHint(addedSeatKey);
  }

  /// Shows a coach mark on the newly seated opponent explaining the
  /// long-press stack ring gesture.
  void _showStackAdjustHint(GlobalKey? seatKey) {
    if (!mounted || seatKey == null || seatKey.currentContext == null) {
      _beginScriptedHand();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'stack_adjust_hint',
        keyTarget: seatKey,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 14,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return buildTooltip(
                title: l10n.guidedStackAdjustTitle,
                body: l10n.guidedStackAdjustBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 12,
      hideSkip: true,
      onFinish: () => _beginScriptedHand(),
      onSkip: () {
        _beginScriptedHand();
        return true;
      },
    );
    coach.show(context: context);
  }

  // ---------------------------------------------------------------------------
  // Drawing Board intro coach mark (explains the table + gestures)
  // ---------------------------------------------------------------------------

  void _showDrawingBoardCoachMark() {
    if (!mounted) return;
    final drawKey = widget.drawingAreaKey;
    if (_drawingBoardShown || drawKey == null || drawKey.currentContext == null) {
      _checkOpponentsBeforeScriptedHand();
      return;
    }
    _drawingBoardShown = true;

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'drawing_board',
        keyTarget: drawKey,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.guidedTableIntroTitle,
                body: l10n.guidedTableIntroBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 12,
      hideSkip: true,
      onFinish: () => _checkOpponentsBeforeScriptedHand(),
      onSkip: () {
        _checkOpponentsBeforeScriptedHand();
        return true;
      },
    );
    coach.show(context: context);
  }

  /// After the drawing board intro, check if we have enough players.
  /// If not, show the "Add Opponents" step before starting the scripted hand.
  void _checkOpponentsBeforeScriptedHand() {
    final count = widget.activePlayerCount?.call() ?? 0;
    if (count >= 2) {
      _beginScriptedHand();
    } else {
      _showAddOpponentsCoachMark();
    }
  }

  // ---------------------------------------------------------------------------
  // Stack Range Ring Coach Mark
  // ---------------------------------------------------------------------------

  void _showStackRingCoachMark(VoidCallback onDone) {
    final ringKey = widget.stackRingKey;
    if (ringKey == null) {
      onDone();
      return;
    }

    // Hide the floating overlay while coach mark is visible
    _animController.reverse();

    // Wait for widget tree to rebuild (current player may have just changed,
    // so StackRangeCircle might not be in the tree yet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (ringKey.currentContext == null) {
          // Key still not rendered — allow retry on next scriptedAction
          _animController.forward();
          onDone();
          return;
        }

        _stackRingTourShown = true;

        final l10n = AppLocalizations.of(context);
        final targets = <TargetFocus>[
          TargetFocus(
            identify: 'stack_ring',
            keyTarget: ringKey,
            shape: ShapeLightFocus.Circle,
            paddingFocus: 20,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (context, controller) {
                  return buildTooltip(
                    title: l10n.guidedStackRingTitle,
                    body: l10n.guidedStackRingBody,
                    onNext: () => controller.next(),
                    context: context,
                    isLast: true,
                  );
                },
              ),
            ],
          ),
        ];

        final coach = TutorialCoachMark(
          targets: targets,
          colorShadow: Colors.black,
          opacityShadow: 0.85,
          paddingFocus: 12,
          hideSkip: true,
          onFinish: () {
            _animController.forward();
            onDone();
          },
          onSkip: () {
            _animController.forward();
            onDone();
            return true;
          },
        );
        coach.show(context: context);
      });
    });
  }

  void _beginScriptedHand() {
    if (!mounted) return;
    _animController.forward();

    if (_isHeroTurn) {
      // Hero is first to act — let them decide
      _setPhase(GuidedPhase.heroTurn);
    } else {
      // Scripted opponent opens with a raise
      OnboardingState.nextScriptedAction = PlayerAction.raise;
      _setPhase(GuidedPhase.scriptedAction);
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive Logic: After scripted action
  // ---------------------------------------------------------------------------

  void _advanceAfterScriptedAction(PlayerAction action) {
    // Track the opener
    if ((action == PlayerAction.raise || action == PlayerAction.bet) &&
        OnboardingState.openerSeat == null) {
      _preflopOpenerDone = true;
    }

    // Check if the betting round is now complete after this scripted action.
    // If so, let auto-advance in poker_hand_screen handle the street transition.
    final roundComplete = widget.isBettingRoundComplete?.call() ?? false;
    if (roundComplete) return;

    // Round not complete — check who acts next
    if (_isHeroTurn) {
      _setPhase(GuidedPhase.heroTurn);
      return;
    }

    // Another NPC needs to act
    _determineNextScriptedAction();
  }

  // ---------------------------------------------------------------------------
  // Reactive Logic: After hero acts
  // ---------------------------------------------------------------------------

  void _advanceAfterHeroAction(PlayerAction action) {
    _doAdvanceAfterHeroAction(action);
  }

  void _doAdvanceAfterHeroAction(PlayerAction action) {
    final round = widget.currentRound;

    if (round == BettingRound.preflop) {
      _handlePostHeroPreflop(action);
    } else {
      _handlePostHeroPostflop(action);
    }
    // If the handler returned without scripting a new phase, the betting round
    // is complete and auto-advance in poker_hand_screen handles the transition.
  }

  void _handlePostHeroPreflop(PlayerAction action) {
    if (action == PlayerAction.fold) {
      OnboardingState.heroFolded = true;
      // If fold leaves only one player, game state handles via "Hand ends" check.
      // If opponents remain (3+ players), script the next one to call.
      final roundComplete = widget.isBettingRoundComplete?.call() ?? false;
      if (roundComplete) return;
      OnboardingState.nextScriptedAction = PlayerAction.call;
      _setPhase(GuidedPhase.scriptedAction);
      return;
    }

    if (action == PlayerAction.raise || action == PlayerAction.bet) {
      _preflopOpenerDone = true;
    }

    // Check if the game state says the round is done (e.g. BB checks option)
    final roundComplete = widget.isBettingRoundComplete?.call() ?? false;
    if (roundComplete) return;

    // Round not complete — next opponent needs to act.
    // After a call: BB still has option (script check).
    // After a raise: opponent calls.
    if (action == PlayerAction.call) {
      OnboardingState.nextScriptedAction = PlayerAction.check;
    } else {
      OnboardingState.nextScriptedAction = PlayerAction.call;
    }
    _setPhase(GuidedPhase.scriptedAction);
  }

  void _handlePostHeroPostflop(PlayerAction action) {
    if (action == PlayerAction.fold) {
      // Hand ends — game state handles via "Hand ends: Only one player remaining"
      return;
    }

    // Check if the round is already complete (e.g. hero called → round done)
    final roundComplete = widget.isBettingRoundComplete?.call() ?? false;
    if (roundComplete) return;

    // Round not complete — script opponent's reaction
    if (action == PlayerAction.check) {
      OnboardingState.nextScriptedAction = PlayerAction.check;
    } else {
      // Hero bet or raised — opponent calls
      OnboardingState.nextScriptedAction = PlayerAction.call;
    }
    _setPhase(GuidedPhase.scriptedAction);
  }

  // ---------------------------------------------------------------------------
  // Determine next scripted action (for non-hero players)
  // ---------------------------------------------------------------------------

  void _determineNextScriptedAction() {
    final round = widget.currentRound;

    if (round == BettingRound.preflop) {
      if (!_preflopOpenerDone) {
        // No one opened yet — script a raise to open the pot
        OnboardingState.nextScriptedAction = PlayerAction.raise;
      } else {
        // After opening — opponent calls (keeps hand alive for teaching)
        OnboardingState.nextScriptedAction = PlayerAction.call;
      }
    } else {
      // Postflop: default to check
      OnboardingState.nextScriptedAction ??= PlayerAction.check;
    }

    _setPhase(GuidedPhase.scriptedAction);
  }

  // ---------------------------------------------------------------------------
  // Start a new postflop street
  // ---------------------------------------------------------------------------

  void _startNewStreet() {
    if (!mounted) return;

    // On a new street, determine who acts first
    // If hero's turn → heroTurn, otherwise → scriptedAction
    if (_isHeroTurn) {
      _setPhase(GuidedPhase.heroTurn);
    } else {
      // Opponent acts first — script a check
      OnboardingState.nextScriptedAction = PlayerAction.check;
      _setPhase(GuidedPhase.scriptedAction);
    }
  }

  // ---------------------------------------------------------------------------
  // Post-hand 1 coach marks: BB pill + Next Hand button spotlights
  // ---------------------------------------------------------------------------

  void _showPostHandCoachMarks() {
    if (!mounted) return;

    final targets = <TargetFocus>[];

    // 1. Blinds pill
    final blindsKey = widget.blindsPillKey;
    if (blindsKey != null && blindsKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'blinds_pill',
          keyTarget: blindsKey,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedBlindsPillTitle,
                  body: l10n.guidedBlindsPillBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    // 2. Next Hand button
    final nextKey = widget.nextHandButtonKey;
    if (nextKey != null && nextKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'next_hand_button',
          keyTarget: nextKey,
          shape: ShapeLightFocus.RRect,
          radius: 40,
          paddingFocus: 4,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedNextHandTitle,
                  body: l10n.guidedNextHandBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    // 3. Undo button (shown after hand completes, not mid-hand)
    final undoKey = widget.undoButtonKey;
    if (!_undoTourShown && !OnboardingState.isReplay &&
        undoKey != null && undoKey.currentContext != null) {
      _undoTourShown = true;
      targets.add(
        TargetFocus(
          identify: 'undo_button',
          keyTarget: undoKey,
          shape: ShapeLightFocus.RRect,
          radius: 24,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedUndoTitle,
                  body: l10n.guidedUndoBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      // No targets available — go straight to prompt
      promptSecondHand();
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      onFinish: () => promptSecondHand(),
      onSkip: () => _finishOnboarding(),
      context: context,
      // Hide skip on the last target (undo button) to avoid overlap.
      showSkipInLastTarget: false,
    );
    coach.show(context: context);
  }

  /// After returning from the first (explain) session-details visit: show a
  /// centered instruction card asking the user to log one more hand — with NO
  /// spotlight. (The Next Hand button is deliberately not highlighted: it skips
  /// the current hand and moves the dealer button, whereas a fresh hand is
  /// already ready to log.) When that hand completes, [onHoleCardsCompleted]
  /// fires the finish-session step. Called by the poker screen once the
  /// session-details screen pops.
  void promptSecondHand() {
    if (!mounted) return;

    final screenHeight = MediaQuery.of(context).size.height;

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'log_one_more_hand',
        // Off-screen target → no spotlight, just a centered card.
        targetPosition: TargetPosition(
          const Size(0, 0),
          const Offset(-1000, -1000),
        ),
        shape: ShapeLightFocus.Circle,
        radius: 0,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(top: screenHeight * 0.32),
            builder: (context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.guidedHandTwoTitle,
                body: l10n.guidedHandTwoBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = createOnboardingCoachMark(
      targets: targets,
      onSkip: () => _finishOnboarding(),
      onFinish: () {
        // Deal a fresh hand with scripted guidance for hand 2.
        OnboardingState.secondTourHandPending = true;
        OnboardingState.resetForSecondHand();
        _preflopOpenerDone = false;
        widget.onDealNextHand?.call();
        // Begin scripted guidance after the new hand renders
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _beginScriptedHand();
          });
        });
      },
      context: context,
    );
    coach.show(context: context);
  }

  /// Spotlights the ⓘ session-details button after hand 2 — asking the user
  /// to return to Session Details to see the stack chart.
  void _showReturnToDetailsCoachMark() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final infoKey = widget.sessionInfoButtonKey;
      if (infoKey == null || infoKey.currentContext == null) {
        // Degrade gracefully — set the flag and let the user navigate manually
        OnboardingState.stackChartReturnTourPending = true;
        OnboardingState.guidedHandPhase = GuidedPhase.done;
        widget.onSkipOrFinish?.call();
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'return_to_details',
          keyTarget: infoKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedReturnToDetailsTitle,
                  body: l10n.guidedReturnToDetailsBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      ];

      final coach = createOnboardingCoachMark(
        targets: targets,
        onSkip: () => _finishOnboarding(),
        onFinish: () {
          // User will now tap ⓘ to return to session details
          OnboardingState.stackChartReturnTourPending = true;
          OnboardingState.guidedHandPhase = GuidedPhase.done;
          widget.onSkipOrFinish?.call();
        },
        context: context,
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setPhase(GuidedPhase phase) {
    if (!mounted) return;

    // Show stack ring coach mark the first time a non-hero player is about to act
    if (phase == GuidedPhase.scriptedAction &&
        !_stackRingTourShown &&
        widget.currentRound == BettingRound.preflop) {
      _showStackRingCoachMark(() {
        _doSetPhase(phase);
      });
      return;
    }

    _doSetPhase(phase);
  }

  void _doSetPhase(GuidedPhase phase) {
    if (!mounted) return;
    OnboardingState.guidedHandPhase = phase;
    if (phase == GuidedPhase.done) {
      _finishOnboarding();
      _animController.reverse();
    } else if (phase == GuidedPhase.boardCards) {
      // Keep the instruction banner visible while the board-cards dialog is up
      // (a prior coach mark may have left the controller reversed).
      _animController.forward();
    }
    setState(() {});
  }

  void _finishOnboarding() {
    final wasReplay = OnboardingState.isReplay;
    OnboardingState.guidedHandPhase = GuidedPhase.done;
    OnboardingState.complete();
    OnboardingPrefs.markOnboardingSeen();
    if (!wasReplay) {
      // Tour skipped mid-hand — the next Home visit shows the post-tour
      // paywall once via the pending flag
      OnboardingPrefs.setPostTourPaywallPending();
    }
    // Notify parent so it can rebuild (e.g. hide progress bar).
    widget.onSkipOrFinish?.call();
  }

  // ---------------------------------------------------------------------------
  // Instruction builders
  // ---------------------------------------------------------------------------

  /// Build the instruction card content for the current phase.
  _InstructionData _buildInstruction() {
    final l10n = AppLocalizations.of(context);
    final phase = OnboardingState.guidedHandPhase;

    switch (phase) {
      case GuidedPhase.scriptedAction:
        return _buildScriptedInstruction(l10n);
      case GuidedPhase.heroTurn:
        return _buildHeroInstruction(l10n);
      case GuidedPhase.boardCards:
        return _buildBoardCardsInstruction(l10n);
      case GuidedPhase.holeCards:
        return _InstructionData(
          title: l10n.guidedReviewHandTitle,
          body: l10n.guidedReviewHandBody,
        );
      case GuidedPhase.handComplete:
        return _InstructionData(
          title: l10n.guidedHandCompleteTitle,
          body: l10n.guidedHandCompleteBody,
          isHighlight: true,
        );
      default:
        return const _InstructionData(title: '', body: '');
    }
  }

  _InstructionData _buildScriptedInstruction(AppLocalizations l10n) {
    final action = OnboardingState.nextScriptedAction ?? PlayerAction.fold;
    final hint = _gestureHint(l10n, action);

    String title;
    String body;

    switch (action) {
      case PlayerAction.raise:
      case PlayerAction.bet:
        title = _preflopOpenerDone ? l10n.guidedActionBet : l10n.guidedOpenThePotTitle;
        body = l10n.guidedBetOnceBody;
        break;
      case PlayerAction.fold:
        title = l10n.guidedFoldTitle;
        body = l10n.guidedFoldBody;
        break;
      case PlayerAction.call:
        title = l10n.guidedCallTitle;
        body = l10n.guidedCallBody;
        break;
      case PlayerAction.check:
        title = l10n.guidedCheckTitle;
        body = l10n.guidedCheckBody;
        break;
      default:
        title = '';
        body = '';
    }

    return _InstructionData(
      title: title,
      body: body,
      gestureHint: hint,
    );
  }

  _InstructionData _buildHeroInstruction(AppLocalizations l10n) {
    // Collect valid actions
    final validActions = <PlayerAction>[];
    for (final a in [
      PlayerAction.check,
      PlayerAction.call,
      PlayerAction.bet,
      PlayerAction.raise,
      PlayerAction.fold,
    ]) {
      if (widget.isValidAction(a)) {
        validActions.add(a);
      }
    }

    // Build the body with gesture hints for each valid action
    final parts = validActions.map((a) {
      final hint = _gestureHint(l10n, a);
      return '${_actionLabel(l10n, a)} ($hint)';
    }).toList();

    String body = parts.join('  ·  ');
    if (validActions.contains(PlayerAction.bet) ||
        validActions.contains(PlayerAction.raise)) {
      body += '\n${l10n.guidedGestureManualBet}';
    }

    return _InstructionData(
      title: l10n.guidedYourTurn,
      body: body,
      isHighlight: true,
    );
  }

  _InstructionData _buildBoardCardsInstruction(AppLocalizations l10n) {
    final round = widget.currentRound;
    switch (round) {
      case BettingRound.flop:
        return _InstructionData(
          title: l10n.guidedDealFlopTitle,
          body: l10n.guidedDealFlopBody,
        );
      case BettingRound.turn:
        return _InstructionData(
          title: l10n.guidedDealTurnTitle,
          body: l10n.guidedDealTurnBody,
        );
      case BettingRound.river:
        return _InstructionData(
          title: l10n.guidedDealRiverTitle,
          body: l10n.guidedDealRiverBody,
        );
      default:
        return const _InstructionData(title: '', body: '');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!OnboardingState.isGuidedHandActive) return const SizedBox.shrink();

    final phase = OnboardingState.guidedHandPhase;
    // These phases are handled via coach marks, not the floating overlay
    if (phase == GuidedPhase.gestureInfo || phase == GuidedPhase.tableButton || phase == GuidedPhase.blindsPill || phase == GuidedPhase.nextHandButton || phase == GuidedPhase.gestureInfoTap) {
      return const SizedBox.shrink();
    }

    final instruction = _buildInstruction();
    if (instruction.title.isEmpty) return const SizedBox.shrink();

    final isHero = phase == GuidedPhase.heroTurn || instruction.isHighlight;

    final screenW = MediaQuery.of(context).size.width;
    final scale = (screenW / 393).clamp(0.8, 1.1);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14 * scale, 6 * scale, 14 * scale, 0),
            child: Container(
              padding: EdgeInsets.fromLTRB(14 * scale, 12 * scale, 14 * scale, 12 * scale),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(
                  color: isHero
                      ? AppColors.accentPrimary.withValues(alpha: 0.6)
                      : AppColors.accentPrimary.withValues(alpha: 0.3),
                  width: isHero ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHero
                        ? AppColors.accentPrimary.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: title + skip
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          instruction.title,
                          style: AppTypography.ibm(
                            color: isHero ? AppColors.accentPrimary : Colors.white,
                            fontSize: (16 * scale).clamp(14.0, 18.0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: skip,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            AppLocalizations.of(context).guidedSkip,
                            style: AppTypography.bodySmall(color: Colors.white60)
                                .copyWith(fontSize: (13 * scale).clamp(11.0, 15.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5 * scale),
                  // Body text
                  Text(
                    instruction.body,
                    style: AppTypography.ibm(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: (14 * scale).clamp(12.0, 16.0),
                      height: 1.5,
                    ),
                  ),
                  if (instruction.gestureHint.isNotEmpty) ...[
                    SizedBox(height: 6 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                      ),
                      child: Text(
                        instruction.gestureHint,
                        style: AppTypography.ibm(
                          color: AppColors.accentPrimary,
                          fontSize: (13 * scale).clamp(11.0, 15.0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 6 * scale),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _actionsCompleted.clamp(0, 12) / 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accentPrimary,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple data holder for instruction card content.
class _InstructionData {
  final String title;
  final String body;
  final String gestureHint;
  final bool isHighlight;

  const _InstructionData({
    required this.title,
    required this.body,
    this.gestureHint = '',
    this.isHighlight = false,
  });
}
