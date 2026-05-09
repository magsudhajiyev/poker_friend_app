import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../models/poker_game_state.dart'; // PlayerAction, BettingRound
import 'onboarding_state.dart';
import 'onboarding_prefs.dart';
import 'onboarding_tour.dart'; // buildTooltip


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

  const GuidedHandOverlay({
    super.key,
    required this.gestureInfoKey,
    this.skipButtonKey,
    this.stackRingKey,
    this.tableButtonKey,
    this.blindsPillKey,
    this.nextHandButtonKey,
    this.sessionInfoButtonKey,
    this.heroSeat,
    this.currentPlayerSeat = 0,
    required this.isValidAction,
    required this.currentRound,
    this.liveCurrentPlayer,
    this.onSkipOrFinish,
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
    if (!OnboardingState.isGuidedHandActive) return;
    if (OnboardingState.guidedHandPhase == GuidedPhase.holeCards) {
      _setPhase(GuidedPhase.handComplete);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && OnboardingState.guidedHandPhase == GuidedPhase.handComplete) {
          _setPhase(GuidedPhase.tableButton);
          _showTableButtonCoachMark();
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
    // Show skip button coach mark before starting the guided hand
    _showSkipButtonCoachMark();
  }

  void _showSkipButtonCoachMark() {
    if (!mounted) return;
    final skipKey = widget.skipButtonKey;
    if (skipKey == null || skipKey.currentContext == null) {
      _beginScriptedHand();
      return;
    }

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'skip_button',
        keyTarget: skipKey,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.guidedSkipButtonTitle,
                body: l10n.guidedSkipButtonBody,
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
        _beginScriptedHand();
      },
      onSkip: () {
        _beginScriptedHand();
        return true;
      },
    );
    coach.show(context: context);
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
      // The player who just acted is the opener (but currentPlayer has already
      // advanced, so the opener was the *previous* player).
      // We'll rely on _preflopOpenerDone flag instead.
      _preflopOpenerDone = true;
    }

    // Check if it's now the hero's turn
    if (_isHeroTurn) {
      _setPhase(GuidedPhase.heroTurn);
      return;
    }

    // Otherwise determine what the next scripted action should be
    _determineNextScriptedAction();
  }

  // ---------------------------------------------------------------------------
  // Reactive Logic: After hero acts
  // ---------------------------------------------------------------------------

  void _advanceAfterHeroAction(PlayerAction action) {
    final round = widget.currentRound;

    if (round == BettingRound.preflop) {
      _handlePostHeroPreflop(action);
    } else {
      _handlePostHeroPostflop(action);
    }
  }

  void _handlePostHeroPreflop(PlayerAction action) {
    if (action == PlayerAction.fold) {
      OnboardingState.heroFolded = true;
      // Next player calls the open, then remaining fold
      OnboardingState.nextScriptedAction = PlayerAction.call;
      _setPhase(GuidedPhase.scriptedAction);
    } else if (action == PlayerAction.call) {
      // Remaining players fold
      OnboardingState.nextScriptedAction = PlayerAction.fold;
      _setPhase(GuidedPhase.scriptedAction);
    } else if (action == PlayerAction.raise || action == PlayerAction.bet) {
      // Hero opened/raised — mark opener done so opponents don't get "Open the Pot"
      _preflopOpenerDone = true;
      // Next opponent calls, remaining fold
      OnboardingState.nextScriptedAction = PlayerAction.call;
      _setPhase(GuidedPhase.scriptedAction);
    }
  }

  void _handlePostHeroPostflop(PlayerAction action) {
    if (action == PlayerAction.fold) {
      // Hand ends — will be caught by onHandComplete
      return;
    } else if (action == PlayerAction.check) {
      // Opponent checks → street ends (auto-advance handles it)
      OnboardingState.nextScriptedAction = PlayerAction.check;
      _setPhase(GuidedPhase.scriptedAction);
    } else if (action == PlayerAction.bet) {
      // Opponent calls
      OnboardingState.nextScriptedAction = PlayerAction.call;
      _setPhase(GuidedPhase.scriptedAction);
    } else if (action == PlayerAction.raise) {
      // Opponent calls the raise
      OnboardingState.nextScriptedAction = PlayerAction.call;
      _setPhase(GuidedPhase.scriptedAction);
    } else if (action == PlayerAction.call) {
      // Hero called opponent's bet → street ends (auto-advance)
      // Nothing to script — auto-advance will trigger onStreetAdvance
    }
  }

  // ---------------------------------------------------------------------------
  // Determine next scripted action (for non-hero players)
  // ---------------------------------------------------------------------------

  void _determineNextScriptedAction() {
    final round = widget.currentRound;

    if (round == BettingRound.preflop) {
      // If opener hasn't acted yet (first action), script a raise
      if (!_preflopOpenerDone) {
        OnboardingState.nextScriptedAction = PlayerAction.raise;
      } else {
        // After hero has acted or for remaining players — fold
        OnboardingState.nextScriptedAction = PlayerAction.fold;
      }
    } else {
      // Postflop: script based on what's needed
      // If no scripted action set, default to check
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
  // Table Button Coach Mark (after hand complete, before menu settings)
  // ---------------------------------------------------------------------------

  void _showTableButtonCoachMark() {
    // Individual mode: skip — not relevant
    if (OnboardingState.isIndividualMode) {
      OnboardingState.guidedHandPhase = GuidedPhase.done;
      widget.onSkipOrFinish?.call();
      return;
    }

    _animController.reverse();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final tableKey = widget.tableButtonKey;
      if (tableKey == null || tableKey.currentContext == null) {
        _setPhase(GuidedPhase.blindsPill);
        _showBlindsPillCoachMark();
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'table_button',
          keyTarget: tableKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedTableButtonTitle,
                  body: l10n.guidedTableButtonBody,
                  onNext: () => controller.next(),
                  context: context,
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
        hideSkip: false,
        skipWidget: _buildSkipWidget(),
        onSkip: () {
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          _setPhase(GuidedPhase.blindsPill);
          _showBlindsPillCoachMark();
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Blinds Pill Coach Mark
  // ---------------------------------------------------------------------------

  void _showBlindsPillCoachMark() {
    _animController.reverse();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final blindsKey = widget.blindsPillKey;
      if (blindsKey == null || blindsKey.currentContext == null) {
        _setPhase(GuidedPhase.nextHandButton);
        _showNextHandButtonCoachMark();
        return;
      }

      final targets = <TargetFocus>[
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
      ];

      final coach = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        opacityShadow: 0.85,
        paddingFocus: 12,
        hideSkip: false,
        skipWidget: _buildSkipWidget(),
        onSkip: () {
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          _setPhase(GuidedPhase.nextHandButton);
          _showNextHandButtonCoachMark();
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Next Hand Button Coach Mark
  // ---------------------------------------------------------------------------

  void _showNextHandButtonCoachMark() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final nextKey = widget.nextHandButtonKey;
      if (nextKey == null || nextKey.currentContext == null) {
        _setPhase(GuidedPhase.gestureInfoTap);
        _showSessionInfoCoachMark();
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'next_hand_button',
          keyTarget: nextKey,
          shape: ShapeLightFocus.RRect,
          radius: 17,
          paddingFocus: 8,
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
      ];

      final coach = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        opacityShadow: 0.85,
        paddingFocus: 12,
        hideSkip: false,
        skipWidget: _buildSkipWidget(),
        onSkip: () {
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          _setPhase(GuidedPhase.gestureInfoTap);
          _showSessionInfoCoachMark();
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Session Info Button Coach Mark — spotlight the ⓘ next to the 3-dot menu
  // ---------------------------------------------------------------------------

  void _showSessionInfoCoachMark() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final infoKey = widget.sessionInfoButtonKey;
      if (infoKey == null || infoKey.currentContext == null) {
        OnboardingState.guidedHandPhase = GuidedPhase.done;
        OnboardingState.advanceTo(5);
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'session_info_button',
          keyTarget: infoKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedSessionInfoTitle,
                  body: l10n.guidedSessionInfoBody,
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
        hideSkip: false,
        skipWidget: _buildSkipWidget(),
        onSkip: () {
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          // Set flag so IndividualSessionTrackingScreen runs its tour
          OnboardingState.sessionDetailsTourPending = true;
          OnboardingState.guidedHandPhase = GuidedPhase.done;
          widget.onSkipOrFinish?.call();
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildSkipWidget() {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(AppLocalizations.of(context).guidedSkip, style: AppTypography.bodySmall(color: Colors.white70).copyWith(fontSize: 15)),
      ),
    );
  }

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
    }
    setState(() {});
  }

  void _finishOnboarding() {
    OnboardingState.guidedHandPhase = GuidedPhase.done;
    OnboardingState.complete();
    OnboardingPrefs.markOnboardingSeen();
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

    return _InstructionData(
      title: l10n.guidedYourTurn,
      body: parts.join('  ·  '),
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

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101115),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHero
                      ? AppColors.buttonPrimary.withValues(alpha: 0.6)
                      : AppColors.buttonPrimary.withValues(alpha: 0.3),
                  width: isHero ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHero
                        ? AppColors.buttonPrimary.withValues(alpha: 0.15)
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
                          style: GoogleFonts.ibmPlexSans(
                            color: isHero ? AppColors.buttonPrimary : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            AppLocalizations.of(context).guidedSkip,
                            style: AppTypography.bodySmall(color: Colors.white60)
                                .copyWith(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Body text
                  Text(
                    instruction.body,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (instruction.gestureHint.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.buttonPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        instruction.gestureHint,
                        style: GoogleFonts.ibmPlexSans(
                          color: AppColors.buttonPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _actionsCompleted.clamp(0, 12) / 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.buttonPrimary,
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
