import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../models/poker_game_state.dart'; // PlayerAction, BettingRound
import 'onboarding_state.dart';
import 'onboarding_prefs.dart';
import 'onboarding_tour.dart'; // buildTooltip


// ---------------------------------------------------------------------------
// Gesture hint strings
// ---------------------------------------------------------------------------
const _gestureHints = <PlayerAction, String>{
  PlayerAction.fold: 'Draw a line ╱',
  PlayerAction.check: 'Tap twice',
  PlayerAction.call: 'Draw ○',
  PlayerAction.bet: 'Tap once',
  PlayerAction.raise: 'Tap once',
};

String _actionLabel(PlayerAction a) {
  switch (a) {
    case PlayerAction.fold:
      return 'Fold';
    case PlayerAction.check:
      return 'Check';
    case PlayerAction.call:
      return 'Call';
    case PlayerAction.bet:
      return 'Bet';
    case PlayerAction.raise:
      return 'Raise';
    case PlayerAction.none:
      return '';
  }
}

/// Floating instruction overlay for the guided example hand (Phase 4).
///
/// Reactive design: instructions adapt to the user's choices when it's their
/// turn, and script opponent actions to keep the hand moving logically.
class GuidedHandOverlay extends StatefulWidget {
  final GlobalKey menuButtonKey;
  final GlobalKey gestureInfoKey;
  final GlobalKey? skipButtonKey;
  final GlobalKey? settingsMenuItemKey;
  /// Callback to programmatically open the 3-dot menu overlay.
  final VoidCallback? onOpenMenu;
  /// Callback to programmatically close the 3-dot menu overlay.
  final VoidCallback? onCloseMenu;
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
    required this.menuButtonKey,
    required this.gestureInfoKey,
    this.skipButtonKey,
    this.settingsMenuItemKey,
    this.onOpenMenu,
    this.onCloseMenu,
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
          _setPhase(GuidedPhase.menuSettings);
          _showMenuSettingsCoachMark();
        }
      });
    }
  }

  /// Called when the hand completes (auto or via winner dialog).
  void onHandComplete() {
    if (!OnboardingState.isGuidedHandActive) return;
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
                return buildTooltip(
                  title: 'Gesture Guide',
                  body: 'Tap this icon anytime to see all gesture controls.',
                  onNext: () => controller.next(),
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
              return buildTooltip(
                title: 'Skip Button',
                body: 'If you skip a hand, this button moves the dealer button to the next player. Keep in mind that stacks will be out of sync — you can update them in Manage Players.',
                onNext: () => controller.next(),
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

  void _beginScriptedHand() {
    if (!mounted) return;
    // First action: UTG opens — scripted raise
    OnboardingState.nextScriptedAction = PlayerAction.raise;
    _setPhase(GuidedPhase.scriptedAction);
    _animController.forward();
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
    } else if (action == PlayerAction.raise) {
      // Opener calls the raise, remaining fold
      // Next action should be call (for opener) or fold (for others)
      // The game engine will route to the correct next player
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
  // Menu Settings Coach Mark (two steps: highlight 3-dots, then Settings item)
  // ---------------------------------------------------------------------------

  void _showMenuSettingsCoachMark() {
    // Individual mode: skip menu/settings step — not relevant
    if (OnboardingState.isIndividualMode) {
      _setPhase(GuidedPhase.endSession);
      _showEndSessionCoachMark();
      return;
    }

    _animController.reverse();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (widget.menuButtonKey.currentContext == null) {
        // Skip straight to end session if menu key not available
        _setPhase(GuidedPhase.endSession);
        _showEndSessionCoachMark();
        return;
      }

      // Step 1: Highlight the 3-dot menu button
      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'menu_for_settings',
          keyTarget: widget.menuButtonKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: 'Game Menu',
                  body: 'This menu has useful options. Let\'s take a look at one important setting.',
                  onNext: () => controller.next(),
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
        skipWidget: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white54),
            ),
            child: Text('Skip', style: AppTypography.bodySmall(color: Colors.white70)),
          ),
        ),
        onSkip: () {
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          // Open the menu overlay, then highlight the Settings item
          _showSettingsItemCoachMark();
        },
      );
      coach.show(context: context);
    });
  }

  void _showSettingsItemCoachMark() {
    // Programmatically open the menu
    widget.onOpenMenu?.call();

    // Wait for the menu overlay to render and the settings key to attach
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final settingsKey = widget.settingsMenuItemKey;
      if (settingsKey == null || settingsKey.currentContext == null) {
        // Settings key not available — skip to end session
        widget.onCloseMenu?.call();
        _setPhase(GuidedPhase.endSession);
        _showEndSessionCoachMark();
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'settings_menu_item',
          keyTarget: settingsKey,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          paddingFocus: 4,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: 'Game Settings',
                  body: 'Here you can change blinds mid-session — useful for tournaments when levels go up.',
                  onNext: () => controller.next(),
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
        skipWidget: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white54),
            ),
            child: Text('Skip', style: AppTypography.bodySmall(color: Colors.white70)),
          ),
        ),
        onSkip: () {
          widget.onCloseMenu?.call();
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          // Close the menu and move to end session coach mark
          widget.onCloseMenu?.call();
          _setPhase(GuidedPhase.endSession);
          _showEndSessionCoachMark();
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // End Session Coach Mark
  // ---------------------------------------------------------------------------

  void _showEndSessionCoachMark() {
    // Individual mode: skip end-session here — handled on tracking screen
    if (OnboardingState.isIndividualMode) {
      OnboardingState.guidedHandPhase = GuidedPhase.done;
      widget.onSkipOrFinish?.call();
      return;
    }

    _animController.reverse();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (widget.menuButtonKey.currentContext == null) return;

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'end_session_menu',
          keyTarget: widget.menuButtonKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: 'End Your Session',
                  body: 'Tap this menu and select "Stop Session" to save your results.',
                  onNext: () => controller.next(),
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
        skipWidget: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white54),
            ),
            child: Text('Skip', style: AppTypography.bodySmall(color: Colors.white70)),
          ),
        ),
        onSkip: () {
          _finishOnboarding();
          return true;
        },
        onFinish: () {
          OnboardingState.guidedHandPhase = GuidedPhase.done;
          OnboardingState.advanceTo(5);
        },
      );
      coach.show(context: context);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setPhase(GuidedPhase phase) {
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
    final phase = OnboardingState.guidedHandPhase;

    switch (phase) {
      case GuidedPhase.scriptedAction:
        return _buildScriptedInstruction();
      case GuidedPhase.heroTurn:
        return _buildHeroInstruction();
      case GuidedPhase.boardCards:
        return _buildBoardCardsInstruction();
      case GuidedPhase.holeCards:
        return const _InstructionData(
          title: 'Review Hand',
          body: 'Enter your hole cards and any notes.',
        );
      case GuidedPhase.handComplete:
        return const _InstructionData(
          title: 'Hand Complete!',
          body: 'Great job! You just logged your first hand.',
          isHighlight: true,
        );
      default:
        return const _InstructionData(title: '', body: '');
    }
  }

  _InstructionData _buildScriptedInstruction() {
    final action = OnboardingState.nextScriptedAction ?? PlayerAction.fold;
    final hint = _gestureHints[action] ?? '';

    String title;
    String body;

    switch (action) {
      case PlayerAction.raise:
      case PlayerAction.bet:
        title = _preflopOpenerDone ? 'Bet' : 'Open the Pot';
        body = 'Tap once to bet.';
        break;
      case PlayerAction.fold:
        title = 'Fold';
        body = 'This player folds. Draw a line to fold.';
        break;
      case PlayerAction.call:
        title = 'Call';
        body = 'This player calls. Draw a circle.';
        break;
      case PlayerAction.check:
        title = 'Check';
        body = 'This player checks. Double tap.';
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

  _InstructionData _buildHeroInstruction() {
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
      final hint = _gestureHints[a] ?? '';
      return '${_actionLabel(a)} ($hint)';
    }).toList();

    return _InstructionData(
      title: 'Your Turn!',
      body: parts.join('  ·  '),
      isHighlight: true,
    );
  }

  _InstructionData _buildBoardCardsInstruction() {
    final round = widget.currentRound;
    switch (round) {
      case BettingRound.flop:
        return const _InstructionData(
          title: 'Deal the Flop',
          body: 'Select 3 cards for the flop.',
        );
      case BettingRound.turn:
        return const _InstructionData(
          title: 'Deal the Turn',
          body: 'Select 1 card for the turn.',
        );
      case BettingRound.river:
        return const _InstructionData(
          title: 'Deal the River',
          body: 'Select 1 card for the river.',
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
    if (phase == GuidedPhase.gestureInfo || phase == GuidedPhase.menuSettings || phase == GuidedPhase.endSession) {
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
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHero
                      ? AppColors.buttonPrimary.withOpacity(0.6)
                      : AppColors.buttonPrimary.withOpacity(0.3),
                  width: isHero ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHero
                        ? AppColors.buttonPrimary.withOpacity(0.15)
                        : Colors.black.withOpacity(0.5),
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
                            fontSize: 16,
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
                            border: Border.all(color: Colors.white38),
                          ),
                          child: Text(
                            'Skip',
                            style: AppTypography.bodySmall(color: Colors.white60)
                                .copyWith(fontSize: 12),
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
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (instruction.gestureHint.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.buttonPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        instruction.gestureHint,
                        style: GoogleFonts.ibmPlexSans(
                          color: AppColors.buttonPrimary,
                          fontSize: 13,
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
                      backgroundColor: Colors.white.withOpacity(0.1),
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
